import XCTest
@testable import SuperTokensIOS

private final class MatrixStorage: TokenStorage {
    private var values: [String: String] = [:]
    func get(_ name: String) -> String? { values[name] }
    func set(_ name: String, value: String) -> Bool { values[name] = value; return true }
    func remove(_ name: String) -> Bool { values.removeValue(forKey: name); return true }
}

private final class MatrixBackend: URLProtocol {
    static var receive: ((MatrixBackend) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let receive = Self.receive else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        receive(self)
    }
    override func stopLoading() {}
    func respond(_ status: Int, headers: [String: String] = [:]) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    func fail() { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)) }
}

final class RefreshCompatibilityMatrixTests: XCTestCase {
    private enum Front { case absent, remove, rotation }
    private enum Observation: Equatable { case event(EventType), post }

    private func front(_ payload: String) -> String {
        return try! JSONSerialization.data(withJSONObject: ["uid": "user", "ate": 9_999_999_999_999, "up": ["value": payload]]).base64EncodedString()
    }

    func testRefreshStatusAndFrontTokenCompatibilityMatrix() throws {
        for status in [200, 419, 403, 500] {
            for frontKind in [Front.absent, .remove, .rotation] {
                try checkRow(status: status, frontKind: frontKind)
            }
        }
    }

    private func checkRow(status: Int, frontKind: Front) throws {
        let label = "status=\(status), front=\(frontKind)"
        SuperTokens.resetForTests()
        let lock = NSLock()
        var observations: [Observation] = []
        try SuperTokens.initialize(apiDomain: "https://api.example.com", sessionExpiredStatusCode: 419, eventHandler: { event in
            lock.lock(); observations.append(.event(event)); lock.unlock()
        }, postAPIHook: { action, _, response in
            XCTAssertEqual(action, .REFRESH_SESSION, label)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, status, label)
            lock.lock(); observations.append(.post); lock.unlock()
        })
        SDKStorage.setTokenStorageForTests(MatrixStorage())
        let oldFront = front("old")
        let newFront = front("new")
        XCTAssertTrue(SuperTokens.installSession(accessToken: "old-access", refreshToken: "old-refresh", frontToken: oldFront, antiCSRFToken: "old-csrf"), label)
        let backendConfiguration = URLSessionConfiguration.ephemeral
        backendConfiguration.protocolClasses = [MatrixBackend.self]
        let backend = URLSession(configuration: backendConfiguration)
        SuperTokensURLProtocol.networkRequestExecutor = { request, completion in
            backend.dataTask(with: request, completionHandler: completion).resume()
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SuperTokensURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            backend.invalidateAndCancel()
            MatrixBackend.receive = nil
            SuperTokens.resetForTests()
        }
        var requests = 0
        var refreshes = 0
        MatrixBackend.receive = { transport in
            if transport.request.url?.path == "/auth/session/refresh" {
                lock.lock(); refreshes += 1; let count = refreshes; lock.unlock()
                guard count == 1 else { XCTFail("Unexpected refresh: \(label)"); transport.fail(); return }
                XCTAssertEqual(transport.request.value(forHTTPHeaderField: "Authorization"), "Bearer old-refresh", label)
                var headers: [String: String] = [:]
                switch frontKind {
                case .absent: break
                case .remove: headers["front-token"] = "remove"
                case .rotation:
                    headers = ["front-token": newFront, "st-access-token": "new-access", "st-refresh-token": "new-refresh", "anti-csrf": "new-csrf"]
                }
                transport.respond(status, headers: headers)
            } else if transport.request.url?.path == "/protected" {
                lock.lock(); requests += 1; let count = requests; lock.unlock()
                guard count <= 2 else { XCTFail("Unexpected retry: \(label)"); transport.fail(); return }
                transport.respond(count == 1 ? 419 : 200)
            } else {
                XCTFail("Unexpected request: \(label)")
                transport.fail()
            }
        }
        let completed = expectation(description: label)
        completed.assertForOverFulfill = true
        session.dataTask(with: URL(string: "https://api.example.com/protected")!) { _, response, error in
            if status >= 300 {
                let expectedError = SuperTokensError.apiError(message: "") as NSError
                XCTAssertEqual((error as NSError?)?.domain, expectedError.domain, label)
                XCTAssertEqual((error as NSError?)?.code, expectedError.code, label)
            } else {
                XCTAssertNil(error, label)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, frontKind == .remove ? 419 : 200, label)
            }
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 5)
        let clears = frontKind == .remove || (frontKind == .absent && status == 419)
        let rotates = frontKind == .rotation
        XCTAssertEqual(SuperTokens.getAccessToken(), clears ? nil : (rotates ? "new-access" : "old-access"), label)
        XCTAssertEqual(SuperTokens.getRefreshToken(), clears ? nil : (rotates ? "new-refresh" : "old-refresh"), label)
        XCTAssertEqual(SuperTokens.getFrontToken(), clears ? nil : (rotates ? newFront : oldFront), label)
        XCTAssertEqual(SuperTokens.getAntiCSRF(), clears ? nil : (rotates ? "new-csrf" : "old-csrf"), label)
        var expected: [Observation] = []
        if rotates { expected.append(.event(.ACCESS_TOKEN_PAYLOAD_UPDATED)) }
        else { expected.append(.event(status == 419 ? .UNAUTHORISED : .SIGN_OUT)) }
        if status == 200 {
            expected.append(.post)
            if !clears { expected.append(.event(.REFRESH_SESSION)) }
        }
        lock.lock(); let actual = observations; let actualRequests = requests; let actualRefreshes = refreshes; lock.unlock()
        XCTAssertEqual(actual, expected, label)
        XCTAssertEqual(actualRefreshes, 1, label)
        XCTAssertEqual(actualRequests, status == 200 && !clears ? 2 : 1, label)
    }
}
