import XCTest
@testable import SuperTokensIOS

private final class GenerationTokenStorage: TokenStorage {
    private var values: [String: String] = [:]
    func get(_ name: String) -> String? { values[name] }
    func set(_ name: String, value: String) -> Bool { values[name] = value; return true }
    func remove(_ name: String) -> Bool { values.removeValue(forKey: name); return true }
}

/// A real URLSession transport with responses released explicitly by each test.
private final class GatedBackend: URLProtocol {
    static var receive: ((GatedBackend) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.receive?(self) }
    override func stopLoading() {}

    func respond(status: Int = 200, headers: [String: String] = [:], body: String = "{\"status\":\"OK\"}") {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    func fail() {
        client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
    }
}

final class SessionGenerationTests: XCTestCase {
    private var backendSession: URLSession!
    private var session: URLSession!
    private let eventsLock = NSLock()
    private var events: [EventType] = []

    override func setUpWithError() throws {
        SuperTokens.resetForTests()
        try SuperTokens.initialize(apiDomain: "https://api.example.com", eventHandler: { event in
            self.eventsLock.lock()
            self.events.append(event)
            self.eventsLock.unlock()
        })
        SDKStorage.setTokenStorageForTests(GenerationTokenStorage())
        let backend = URLSessionConfiguration.ephemeral
        backend.protocolClasses = [GatedBackend.self]
        backendSession = URLSession(configuration: backend)
        SuperTokensURLProtocol.networkRequestExecutor = { request, completion in
            self.backendSession.dataTask(with: request, completionHandler: completion).resume()
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuperTokensURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        backendSession.invalidateAndCancel()
        GatedBackend.receive = nil
        SuperTokens.resetForTests()
        super.tearDown()
    }

    private func front(_ user: String) -> String {
        try! JSONSerialization.data(withJSONObject: ["uid": user, "ate": 9_999_999_999_999, "up": ["user": user]]).base64EncodedString()
    }

    private func install(_ user: String) {
        XCTAssertTrue(SuperTokens.installSession(accessToken: "\(user)-access", refreshToken: "\(user)-refresh", frontToken: front(user), antiCSRFToken: "\(user)-csrf"))
    }

    private func clearEvents() {
        eventsLock.lock()
        events.removeAll()
        eventsLock.unlock()
    }

    private func recordedEvents() -> [EventType] {
        eventsLock.lock()
        defer { eventsLock.unlock() }
        return events
    }

    func testLateRefreshAfterInstallCannotWriteOrEmitEvents() {
        assertLateRefresh(status: 200)
    }

    func testLateRefresh401AfterInstallCannotClearOrEmitEvents() {
        assertLateRefresh(status: 401)
    }

    func testOrdinaryRequestRetriesReplacementAfterLateRefresh() {
        install("old")
        let refreshStarted = expectation(description: "refresh reached transport")
        let finished = expectation(description: "request retried")
        var refreshGate: GatedBackend?
        GatedBackend.receive = { transport in
            switch transport.request.url!.path {
            case "/auth/session/refresh":
                refreshGate = transport
                refreshStarted.fulfill()
            default:
                if transport.request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
                    transport.respond(status: 401)
                } else {
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer new-access")
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "new-csrf")
                    transport.respond()
                }
            }
        }
        session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            finished.fulfill()
        }.resume()
        wait(for: [refreshStarted], timeout: 3)
        install("new")
        let replacement = SuperTokens.getSessionSnapshot()
        clearEvents()
        refreshGate?.respond(status: 401, headers: ["front-token": "remove"])
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), replacement)
        XCTAssertTrue(recordedEvents().isEmpty)
    }

    private func assertLateRefresh(status: Int) {
        install("old")
        let started = expectation(description: "refresh reached transport")
        let finished = expectation(description: "refresh completed")
        var responseGate: GatedBackend?
        GatedBackend.receive = { transport in
            XCTAssertEqual(transport.request.url?.path, "/auth/session/refresh")
            XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-refresh")
            XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "old-csrf")
            responseGate = transport
            started.fulfill()
        }
        DispatchQueue.global().async {
            do {
                let refreshed = try SuperTokens.attemptRefreshingSession()
                XCTAssertTrue(refreshed)
            } catch {
                XCTFail("Refresh failed: \(error)")
            }
            finished.fulfill()
        }
        wait(for: [started], timeout: 3)
        install("new")
        let replacement = SuperTokens.getSessionSnapshot()
        clearEvents()
        responseGate?.respond(status: status, headers: status == 401 ? ["front-token": "remove"] : [
            "st-access-token": "stale-access", "st-refresh-token": "stale-refresh",
            "front-token": front("old"), "anti-csrf": "stale-csrf"
        ])
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), replacement)
        XCTAssertTrue(recordedEvents().isEmpty)
    }

    func testLateOrdinaryResponseAfterClearCannotRestoreSessionOrEmitEvents() {
        install("old")
        let started = expectation(description: "ordinary request reached transport")
        let finished = expectation(description: "ordinary request completed")
        var responseGate: GatedBackend?
        GatedBackend.receive = { transport in
            XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-access")
            responseGate = transport
            started.fulfill()
        }
        session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            finished.fulfill()
        }.resume()
        wait(for: [started], timeout: 3)
        XCTAssertTrue(SuperTokens.clearSession(expectedGeneration: SuperTokens.getSessionSnapshot().generation))
        let cleared = SuperTokens.getSessionSnapshot()
        clearEvents()
        responseGate?.respond(headers: ["st-access-token": "stale-access", "st-refresh-token": "stale-refresh", "front-token": front("old")])
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), cleared)
        XCTAssertTrue(recordedEvents().isEmpty)
    }

    func testLegacyTokenWriteInvalidatesInFlightResponse() {
        install("old")
        let started = expectation(description: "request reached transport")
        let finished = expectation(description: "request completed")
        var responseGate: GatedBackend?
        GatedBackend.receive = { transport in
            responseGate = transport
            started.fulfill()
        }
        session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, _, error in
            XCTAssertNil(error)
            finished.fulfill()
        }.resume()
        wait(for: [started], timeout: 3)
        let generation = SuperTokens.getSessionSnapshot().generation
        XCTAssertTrue(Utils.setToken(tokenType: .access, value: "legacy-access"))
        let replacement = SuperTokens.getSessionSnapshot()
        XCTAssertNotEqual(replacement.generation, generation)
        clearEvents()
        responseGate?.respond(headers: ["front-token": "remove"])
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), replacement)
        XCTAssertTrue(recordedEvents().isEmpty)
    }

    func testLateSignOutAfterInstallCannotClearReplacementOrEmitEvents() {
        install("old")
        let started = expectation(description: "signout reached transport")
        let finished = expectation(description: "signout completed")
        var responseGate: GatedBackend?
        GatedBackend.receive = { transport in
            XCTAssertEqual(transport.request.url?.path, "/auth/signout")
            XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-access")
            responseGate = transport
            started.fulfill()
        }
        var postHookCount = 0
        SuperTokens.config!.postAPIHook = { _, _, _ in postHookCount += 1 }
        SuperTokens.signOut { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        wait(for: [started], timeout: 3)
        install("new")
        let replacement = SuperTokens.getSessionSnapshot()
        clearEvents()
        responseGate?.respond(headers: ["front-token": "remove"])
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), replacement)
        XCTAssertTrue(recordedEvents().isEmpty)
        XCTAssertEqual(postHookCount, 0)
    }

    func testLateSignOutSuccessAfterLocalClearDoesNotRunPostHook() {
        assertLateSignOutAfterClear(replaceFirst: false, fail: false)
    }

    func testLateSignOutErrorAfterLocalClearDoesNotReportObsoleteError() {
        assertLateSignOutAfterClear(replaceFirst: false, fail: true)
    }

    func testLateSignOutSuccessAfterReplacementAndClearDoesNotRunPostHook() {
        assertLateSignOutAfterClear(replaceFirst: true, fail: false)
    }

    private func assertLateSignOutAfterClear(replaceFirst: Bool, fail: Bool) {
        install("old")
        let started = expectation(description: "signout reached transport")
        let finished = expectation(description: "signout completed")
        var responseGate: GatedBackend?
        var postHooks = 0
        SuperTokens.config!.postAPIHook = { _, _, _ in postHooks += 1 }
        GatedBackend.receive = { transport in responseGate = transport; started.fulfill() }
        SuperTokens.signOut { error in
            XCTAssertNil(error)
            finished.fulfill()
        }
        wait(for: [started], timeout: 3)
        if replaceFirst { install("new") }
        XCTAssertTrue(SuperTokens.clearSessionLocally())
        if fail { responseGate?.fail() } else { responseGate?.respond(headers: ["front-token": "remove"]) }
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(postHooks, 0)
    }

    func testAcceptedSignOutClearRunsPostHookOnce() {
        install("old")
        clearEvents()
        let finished = expectation(description: "signout completed")
        finished.assertForOverFulfill = true
        var preHooks = 0
        var postHooks = 0
        SuperTokens.config!.preAPIHook = { action, request in
            XCTAssertEqual(action, .SIGN_OUT)
            XCTAssertEqual(request.url?.path, "/auth/signout")
            XCTAssertEqual(request.httpMethod, "POST")
            preHooks += 1
            return request
        }
        SuperTokens.config!.postAPIHook = { action, request, response in
            XCTAssertEqual(action, .SIGN_OUT)
            XCTAssertEqual(request.url?.path, "/auth/signout")
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            postHooks += 1
        }
        GatedBackend.receive = { $0.respond(headers: ["front-token": "remove"]) }
        SuperTokens.signOut { error in XCTAssertNil(error); finished.fulfill() }
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(preHooks, 1)
        XCTAssertEqual(postHooks, 1)
        XCTAssertFalse(SuperTokens.getSessionSnapshot().sessionExists)
        XCTAssertEqual(recordedEvents().filter { $0 == .SIGN_OUT }.count, 1)
    }

    func testCurrentSignOutAPIErrorPreservesSession() {
        assertCurrentSignOutFailure(networkError: false)
    }

    func testCurrentSignOutNetworkErrorPreservesSession() {
        assertCurrentSignOutFailure(networkError: true)
    }

    private func assertCurrentSignOutFailure(networkError: Bool) {
        install("old")
        let before = SuperTokens.getSessionSnapshot()
        clearEvents()
        let finished = expectation(description: "signout completes once")
        finished.assertForOverFulfill = true
        var preHooks = 0
        var postHooks = 0
        SuperTokens.config!.preAPIHook = { action, request in
            XCTAssertEqual(action, .SIGN_OUT)
            XCTAssertEqual(request.url?.path, "/auth/signout")
            XCTAssertEqual(request.httpMethod, "POST")
            preHooks += 1
            return request
        }
        SuperTokens.config!.postAPIHook = { _, _, _ in postHooks += 1 }
        GatedBackend.receive = { transport in
            XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-access")
            if networkError { transport.fail() } else { transport.respond(status: 500) }
        }
        SuperTokens.signOut { error in
            XCTAssertNotNil(error)
            finished.fulfill()
        }
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(preHooks, 1)
        XCTAssertEqual(postHooks, 0)
        XCTAssertTrue(recordedEvents().isEmpty)
        XCTAssertTrue(SuperTokens.doesSessionExist())
        XCTAssertEqual(SuperTokens.getSessionSnapshot(), before)
    }

    func testConcurrentRequestsRefreshSuccessfully() {
        assertConcurrentRefresh(outcome: .success)
    }

    func testConcurrentRequestsHandleTerminalRefresh401() {
        assertConcurrentRefresh(outcome: .unauthorized)
    }

    func testConcurrentRequestsRecoverAfterRefreshDisconnect() {
        assertConcurrentRefresh(outcome: .disconnect)
    }

    func testCallerHeadersAndAuthorizationSurviveRefreshRetryWhileOtherDomainIsExcluded() {
        install("old")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuperTokensURLProtocol.self, GatedBackend.self]
        let intercepted = URLSession(configuration: configuration)
        defer { intercepted.invalidateAndCancel() }
        let finished = expectation(description: "matching request retried")
        let excluded = expectation(description: "excluded request bypassed SDK")
        var matchingRequests = 0
        var refreshRequests = 0
        let lock = NSLock()
        GatedBackend.receive = { transport in
            let request = transport.request
            if request.url?.host == "other.example.com" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer caller")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Caller"), "custom")
                XCTAssertNil(request.value(forHTTPHeaderField: "anti-csrf"))
                XCTAssertNil(request.value(forHTTPHeaderField: "st-auth-mode"))
                transport.respond()
                return
            }
            if request.url?.path == "/auth/session/refresh" {
                lock.lock(); refreshRequests += 1; lock.unlock()
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-refresh")
                XCTAssertEqual(request.value(forHTTPHeaderField: "anti-csrf"), "old-csrf")
                transport.respond(headers: ["st-access-token": "rotated-access", "st-refresh-token": "rotated-refresh", "front-token": self.front("old"), "anti-csrf": "rotated-csrf"])
                return
            }
            lock.lock(); matchingRequests += 1; let attempt = matchingRequests; lock.unlock()
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer caller")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Caller"), "custom")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anti-csrf"), attempt == 1 ? "old-csrf" : "rotated-csrf")
            transport.respond(status: attempt == 1 ? 401 : 200)
        }
        func request(_ host: String) -> URLRequest {
            var request = URLRequest(url: URL(string: "https://\(host)/protected")!)
            request.setValue("Bearer caller", forHTTPHeaderField: "Authorization")
            request.setValue("custom", forHTTPHeaderField: "X-Caller")
            return request
        }
        intercepted.dataTask(with: request("other.example.com")) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            excluded.fulfill()
        }.resume()
        wait(for: [excluded], timeout: 3)
        intercepted.dataTask(with: request("api.example.com")) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            finished.fulfill()
        }.resume()
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(matchingRequests, 2)
        XCTAssertEqual(refreshRequests, 1)
        XCTAssertEqual(SuperTokens.getAccessToken(), "rotated-access")
    }

    func testValidPublicGettersDoNotRefresh() throws {
        install("old")
        GatedBackend.receive = { _ in XCTFail("Valid getters should not make a request") }
        XCTAssertTrue(SuperTokens.doesSessionExist())
        XCTAssertEqual(try SuperTokens.getUserId(), "old")
        XCTAssertEqual(try SuperTokens.getAccessTokenPayloadSecurely()["user"] as? String, "old")
        XCTAssertEqual(SuperTokens.getAccessToken(), "old-access")
    }

    func testExpiredPublicGetterRefreshesSuccessfully() {
        assertExpiredGetter(outcome: .success)
    }

    func testExpiredPublicGetterReportsRefresh401() {
        assertExpiredGetter(outcome: .unauthorized)
    }

    func testExpiredPublicGetterReportsRefreshDisconnect() {
        assertExpiredGetter(outcome: .disconnect)
    }

    private func assertExpiredGetter(outcome: RefreshOutcome) {
        let expired = try! JSONSerialization.data(withJSONObject: ["uid": "old", "ate": 1, "up": ["user": "old"]]).base64EncodedString()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "old-access", refreshToken: "old-refresh", frontToken: expired, antiCSRFToken: "old-csrf"))
        let before = SuperTokens.getSessionSnapshot()
        XCTAssertEqual(try? SuperTokens.getUserId(), "old")
        let done = expectation(description: "expired getter completes")
        GatedBackend.receive = { transport in
            XCTAssertEqual(transport.request.url?.path, "/auth/session/refresh")
            switch outcome {
            case .success:
                transport.respond(headers: ["st-access-token": "rotated-access", "st-refresh-token": "rotated-refresh", "front-token": self.front("old")])
            case .unauthorized: transport.respond(status: 401, headers: ["front-token": "remove"])
            case .disconnect: transport.fail()
            }
        }
        DispatchQueue.global().async {
            do {
            switch outcome {
            case .success:
                XCTAssertTrue(SuperTokens.doesSessionExist())
                XCTAssertEqual(SuperTokens.getAccessToken(), "rotated-access")
                XCTAssertEqual(try? SuperTokens.getAccessTokenPayloadSecurely()["user"] as? String, "old")
            case .unauthorized:
                XCTAssertFalse(SuperTokens.doesSessionExist())
                XCTAssertNil(SuperTokens.getAccessToken())
                XCTAssertThrowsError(try SuperTokens.getUserId())
            case .disconnect:
                XCTAssertFalse(SuperTokens.doesSessionExist())
                XCTAssertEqual(SuperTokens.getRefreshToken(), "old-refresh")
                XCTAssertEqual(SuperTokens.getFrontToken(), expired)
                XCTAssertThrowsError(try SuperTokens.getAccessTokenPayloadSecurely())
                XCTAssertEqual(SuperTokens.getSessionSnapshot(), before)
            }
            } catch {
                XCTFail("Unexpected getter error: \(error)")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testRealKeychainRestoresPublicGettersAfterReinitialization() throws {
        let domain = "https://\(UUID().uuidString.lowercased()).example.com"
        SuperTokens.isInitCalled = false
        try SuperTokens.initialize(apiDomain: domain)
        let token = front("keychain-user")
        XCTAssertTrue(SuperTokens.installSession(accessToken: "keychain-access", refreshToken: "keychain-refresh", frontToken: token, antiCSRFToken: "keychain-csrf"))
        SuperTokens.isInitCalled = false
        try SuperTokens.initialize(apiDomain: domain)
        XCTAssertTrue(SuperTokens.doesSessionExist())
        XCTAssertEqual(try SuperTokens.getUserId(), "keychain-user")
        XCTAssertEqual(SuperTokens.getAccessToken(), "keychain-access")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "keychain-refresh")
        XCTAssertEqual(SuperTokens.getFrontToken(), token)
        XCTAssertEqual(SuperTokens.getAntiCSRF(), "keychain-csrf")
        XCTAssertTrue(SuperTokens.clearSessionLocally())
    }

    private enum RefreshOutcome { case success, unauthorized, disconnect }

    private func assertConcurrentRefresh(outcome: RefreshOutcome) {
        install("old")
        let before = SuperTokens.getSessionSnapshot()
        clearEvents()
        let rotatedFront = front("old")
        let count = 4
        let originals = expectation(description: "original requests reached transport")
        originals.expectedFulfillmentCount = count
        let refreshStarted = expectation(description: "first refresh reached transport")
        let completed = expectation(description: "all callers completed")
        completed.expectedFulfillmentCount = count
        completed.assertForOverFulfill = true
        let lock = NSLock()
        var originalGates: [GatedBackend] = []
        var firstRefresh: GatedBackend?
        var refreshCount = 0
        var retries = 0
        var preHooks = 0
        var postHooks = 0
        SuperTokens.config!.preAPIHook = { action, request in
            XCTAssertEqual(action, .REFRESH_SESSION)
            XCTAssertEqual(request.url?.path, "/auth/session/refresh")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anti-csrf"), "old-csrf")
            lock.lock(); preHooks += 1; lock.unlock()
            return request
        }
        SuperTokens.config!.postAPIHook = { action, request, response in
            XCTAssertEqual(action, .REFRESH_SESSION)
            XCTAssertEqual(request.url?.path, "/auth/session/refresh")
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            lock.lock(); postHooks += 1; lock.unlock()
        }
        func resolveRefresh(_ transport: GatedBackend) {
            switch outcome {
            case .success:
                transport.respond(headers: ["st-access-token": "rotated-access", "st-refresh-token": "rotated-refresh", "front-token": rotatedFront, "anti-csrf": "rotated-csrf"])
            case .unauthorized: transport.respond(status: 401, headers: ["front-token": "remove"])
            case .disconnect: transport.fail()
            }
        }
        GatedBackend.receive = { transport in
            if transport.request.url?.path == "/auth/session/refresh" {
                XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-refresh")
                XCTAssertEqual(transport.request.httpMethod, "POST")
                XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "old-csrf")
                lock.lock()
                refreshCount += 1
                let isFirst = firstRefresh == nil
                if isFirst { firstRefresh = transport }
                lock.unlock()
                if isFirst { refreshStarted.fulfill() } else { resolveRefresh(transport) }
            } else if transport.request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
                lock.lock(); originalGates.append(transport); lock.unlock()
                originals.fulfill()
            } else {
                XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer rotated-access")
                XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "rotated-csrf")
                lock.lock(); retries += 1; lock.unlock()
                transport.respond()
            }
        }
        for _ in 0..<count {
            session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, response, error in
                switch outcome {
                case .success:
                    XCTAssertNil(error)
                    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                case .unauthorized:
                    XCTAssertNotNil(error)
                case .disconnect:
                    XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost)
                }
                completed.fulfill()
            }.resume()
        }
        wait(for: [originals], timeout: 3)
        lock.lock(); let gates = originalGates; lock.unlock()
        gates.forEach { $0.respond(status: 401) }
        wait(for: [refreshStarted], timeout: 3)
        lock.lock(); let gate = firstRefresh; lock.unlock()
        if let gate { resolveRefresh(gate) }
        wait(for: [completed], timeout: 5)
        lock.lock(); let observedRefreshes = refreshCount; let observedRetries = retries; let observedPre = preHooks; let observedPost = postHooks; lock.unlock()
        XCTAssertEqual(observedPre, observedRefreshes)
        switch outcome {
        case .success:
            XCTAssertEqual(observedRefreshes, 1)
            XCTAssertEqual(observedRetries, count)
            XCTAssertEqual(observedPost, 1)
            XCTAssertEqual(SuperTokens.getAccessToken(), "rotated-access")
            let after = SuperTokens.getSessionSnapshot()
            XCTAssertEqual(after.generation, before.generation)
            XCTAssertEqual(after.refreshToken, "rotated-refresh")
            XCTAssertEqual(after.frontToken, rotatedFront)
            XCTAssertEqual(after.antiCSRFToken, "rotated-csrf")
            XCTAssertNotNil(after.lastAccessTokenUpdate)
            XCTAssertEqual(recordedEvents().filter { $0 == .REFRESH_SESSION }.count, 1)
        case .unauthorized:
            XCTAssertEqual(observedPost, 0)
            XCTAssertFalse(SuperTokens.doesSessionExist())
            let after = SuperTokens.getSessionSnapshot()
            XCTAssertNil(after.accessToken)
            XCTAssertNil(after.refreshToken)
            XCTAssertNil(after.frontToken)
            XCTAssertNil(after.antiCSRFToken)
            XCTAssertNil(after.lastAccessTokenUpdate)
            XCTAssertTrue(recordedEvents().contains(.UNAUTHORISED))
            XCTAssertFalse(recordedEvents().contains(.REFRESH_SESSION))
        case .disconnect:
            XCTAssertEqual(observedPost, 0)
            XCTAssertTrue(SuperTokens.doesSessionExist())
            XCTAssertEqual(SuperTokens.getSessionSnapshot(), before)
            XCTAssertFalse(recordedEvents().contains(.REFRESH_SESSION))
            let recovered = expectation(description: "later request refreshes and completes")
            var recoveryRefreshes = 0
            var recoveryRetries = 0
            GatedBackend.receive = { transport in
                if transport.request.url?.path == "/auth/session/refresh" {
                    XCTAssertEqual(transport.request.httpMethod, "POST")
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-refresh")
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "old-csrf")
                    lock.lock(); recoveryRefreshes += 1; lock.unlock()
                    transport.respond(headers: ["st-access-token": "rotated-access", "st-refresh-token": "rotated-refresh", "front-token": rotatedFront, "anti-csrf": "rotated-csrf"])
                } else if transport.request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
                    transport.respond(status: 401)
                } else {
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer rotated-access")
                    XCTAssertEqual(transport.request.value(forHTTPHeaderField: "anti-csrf"), "rotated-csrf")
                    lock.lock(); recoveryRetries += 1; lock.unlock()
                    transport.respond()
                }
            }
            session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, response, error in
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                recovered.fulfill()
            }.resume()
            wait(for: [recovered], timeout: 5)
            XCTAssertEqual(SuperTokens.getAccessToken(), "rotated-access")
            lock.lock(); let finalPre = preHooks; let finalPost = postHooks; let finalRefreshes = recoveryRefreshes; let finalRetries = recoveryRetries; lock.unlock()
            XCTAssertEqual(finalPre, observedPre + 1)
            XCTAssertEqual(finalPost, observedPost + 1)
            XCTAssertEqual(finalRefreshes, 1)
            XCTAssertEqual(finalRetries, 1)
            XCTAssertEqual(recordedEvents().filter { $0 == .REFRESH_SESSION }.count, 1)
        }
    }

    func testDelayedLifecycleEventCarriesClearGenerationAndCannotClearReplacement() {
        install("old")
        let admitted = expectation(description: "event admitted")
        let delivered = expectation(description: "event delivered")
        let finished = expectation(description: "request finished")
        let release = DispatchSemaphore(value: 0)
        var observed: SessionLifecycleEvent?
        SessionStateCoordinator.beforeLifecycleDeliveryForTests = {
            admitted.fulfill()
            _ = release.wait(timeout: .now() + 3)
        }
        let id = SuperTokens.addLifecycleListener { event in
            observed = event
            XCTAssertFalse(SuperTokens.clearSession(expectedGeneration: event.generation))
            XCTAssertFalse(SuperTokens.installSession(expectedGeneration: event.generation, accessToken: "stale", refreshToken: "stale", frontToken: self.front("stale")))
            delivered.fulfill()
        }
        GatedBackend.receive = { $0.respond(headers: ["front-token": "remove"]) }
        session.dataTask(with: URL(string: "https://api.example.com/logout")!) { _, _, _ in finished.fulfill() }.resume()
        wait(for: [admitted], timeout: 3)
        let clearedGeneration = SuperTokens.getSessionSnapshot().generation
        SuperTokens.removeLifecycleListener(id)
        install("new")
        release.signal()
        wait(for: [delivered, finished], timeout: 3)
        XCTAssertEqual(observed?.type, .SIGN_OUT)
        XCTAssertEqual(observed?.generation, clearedGeneration)
        XCTAssertEqual(SuperTokens.getSessionSnapshot().accessToken, "new-access")
        XCTAssertTrue(recordedEvents().contains(.SIGN_OUT))
    }

    func testRemovedLifecycleListenerIsNotAdmitted() {
        install("old")
        let completed = expectation(description: "request completed")
        var calls = 0
        let id = SuperTokens.addLifecycleListener { _ in calls += 1 }
        SuperTokens.removeLifecycleListener(id)
        GatedBackend.receive = { $0.respond(headers: ["front-token": "remove"]) }
        session.dataTask(with: URL(string: "https://api.example.com/logout")!) { _, _, _ in completed.fulfill() }.resume()
        wait(for: [completed], timeout: 3)
        XCTAssertEqual(calls, 0)
    }

    func testClearLifecycleGenerationPermitsConditionalActionAndUnregister() {
        install("old")
        let delivered = expectation(description: "clear event")
        let completed = expectation(description: "request completed")
        var id: UUID!
        id = SuperTokens.addLifecycleListener { event in
            XCTAssertEqual(event.type, .SIGN_OUT)
            XCTAssertEqual(event.generation, SuperTokens.getSessionSnapshot().generation)
            SuperTokens.removeLifecycleListener(id)
            XCTAssertTrue(SuperTokens.clearSession(expectedGeneration: event.generation))
            XCTAssertTrue(SuperTokens.installSession(expectedGeneration: SuperTokens.getSessionSnapshot().generation,
                                                      accessToken: "reentrant-access", refreshToken: "reentrant-refresh", frontToken: self.front("reentrant")))
            delivered.fulfill()
        }
        GatedBackend.receive = { $0.respond(headers: ["front-token": "remove"]) }
        session.dataTask(with: URL(string: "https://api.example.com/logout")!) { _, _, _ in completed.fulfill() }.resume()
        wait(for: [delivered, completed], timeout: 3)
        XCTAssertEqual(SuperTokens.getSessionSnapshot().accessToken, "reentrant-access")
    }

    func testLifecycleListenerCanSynchronouslyRefreshWithoutDeadlock() {
        let delivered = expectation(description: "session created callback")
        let completed = expectation(description: "request completed")
        let initialGeneration = SuperTokens.getSessionSnapshot().generation
        var createdGeneration: UInt64?
        var refreshGeneration: UInt64?
        SuperTokensURLProtocol.networkRequestExecutor = { request, completion in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [GatedBackend.self]
            let transport = URLSession(configuration: configuration)
            transport.dataTask(with: request) { data, response, error in
                completion(data, response, error)
                transport.finishTasksAndInvalidate()
            }.resume()
        }
        let id = SuperTokens.addLifecycleListener { event in
            switch event.type {
            case .SESSION_CREATED:
                createdGeneration = event.generation
                do { XCTAssertTrue(try SuperTokens.attemptRefreshingSession()) }
                catch { XCTFail("Refresh failed: \(error)") }
                delivered.fulfill()
            case .REFRESH_SESSION:
                refreshGeneration = event.generation
            default: break
            }
        }
        GatedBackend.receive = { transport in
            if transport.request.url?.path == "/auth/session/refresh" {
                transport.respond(headers: ["st-access-token": "rotated-access", "st-refresh-token": "rotated-refresh", "front-token": self.front("user")])
            } else {
                transport.respond(headers: ["st-access-token": "access", "st-refresh-token": "refresh", "front-token": self.front("user")])
            }
        }
        session.dataTask(with: URL(string: "https://api.example.com/login")!) { _, _, _ in completed.fulfill() }.resume()
        wait(for: [delivered, completed], timeout: 3)
        XCTAssertEqual(createdGeneration, initialGeneration + 1)
        XCTAssertEqual(refreshGeneration, createdGeneration)
        XCTAssertEqual(SuperTokens.getSessionSnapshot().accessToken, "rotated-access")
        SuperTokens.removeLifecycleListener(id)
    }

    func testConcurrentInstallAndClearHaveExactlyOneCASWinner() {
        install("old")
        let generation = SuperTokens.getSessionSnapshot().generation
        let resultsLock = NSLock()
        var successes = 0
        DispatchQueue.concurrentPerform(iterations: 32) { index in
            let success: Bool
            if index.isMultiple(of: 2) {
                success = SuperTokens.installSession(expectedGeneration: generation, accessToken: "new-access", refreshToken: "new-refresh", frontToken: front("new"))
            } else {
                success = SuperTokens.clearSession(expectedGeneration: generation)
            }
            resultsLock.lock()
            if success { successes += 1 }
            resultsLock.unlock()
        }
        XCTAssertEqual(successes, 1)
        XCTAssertEqual(SuperTokens.getSessionSnapshot().generation, generation + 1)
    }

    private func accessToken(handle: String, revision: Int) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: ["sessionHandle": handle, "sub": "user", "revision": revision])
        let encoded = payload.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "e30.\(encoded).signature"
    }

    func testOrdinarySameSessionTokenRotationRetainsGeneration() {
        assertOrdinaryRotation(incomingHandle: "session-a", replacesSession: false)
    }

    func testOrdinarySameUserNewSessionChangesGeneration() {
        assertOrdinaryRotation(incomingHandle: "session-b", replacesSession: true)
    }

    private func assertOrdinaryRotation(incomingHandle: String, replacesSession: Bool) {
        XCTAssertTrue(SuperTokens.installSession(accessToken: accessToken(handle: "session-a", revision: 1), refreshToken: "old-refresh", frontToken: front("user")))
        let before = SuperTokens.getSessionSnapshot()
        let finished = expectation(description: "rotation completed")
        let newAccess = accessToken(handle: incomingHandle, revision: 2)
        GatedBackend.receive = { transport in
            transport.respond(headers: ["st-access-token": newAccess, "st-refresh-token": "new-refresh", "front-token": self.front("user")])
        }
        session.dataTask(with: URL(string: "https://api.example.com/rotate")!) { _, _, error in
            XCTAssertNil(error)
            finished.fulfill()
        }.resume()
        wait(for: [finished], timeout: 3)
        let after = SuperTokens.getSessionSnapshot()
        XCTAssertEqual(after.generation, before.generation + (replacesSession ? 1 : 0))
        XCTAssertEqual(after.accessToken, newAccess)
        XCTAssertEqual(after.refreshToken, "new-refresh")
    }

    func testListenerCanReadClearAndRemoveItselfWithoutDeadlock() {
        let finished = expectation(description: "reentrant listener completed")
        var id: UUID!
        var received: [SessionSnapshot] = []
        id = SuperTokens.addSessionListener { snapshot in
            received.append(snapshot)
            XCTAssertEqual(SuperTokens.getSessionSnapshot(), snapshot)
            SuperTokens.removeSessionListener(id)
            XCTAssertTrue(SuperTokens.clearSession(expectedGeneration: snapshot.generation))
        }
        DispatchQueue.global().async {
            self.install("new")
            finished.fulfill()
        }
        wait(for: [finished], timeout: 3)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].accessToken, "new-access")
        XCTAssertFalse(SuperTokens.getSessionSnapshot().sessionExists)
        XCTAssertTrue(recordedEvents().isEmpty)
    }
}
