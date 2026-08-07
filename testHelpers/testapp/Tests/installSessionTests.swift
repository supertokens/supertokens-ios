import XCTest
@testable import SuperTokensIOS

private enum TokenStorageOperation: Equatable {
    case set(name: String, value: String)
    case remove(name: String)
}

private final class FakeTokenStorage: TokenStorage {
    var values: [String: String] = [:]
    var failSetKeys: Set<String> = []
    var failRemoveKeys: Set<String> = []
    var operations: [TokenStorageOperation] = []
    func get(_ name: String) -> String? { values[name] }
    func set(_ name: String, value: String) -> Bool {
        operations.append(.set(name: name, value: value))
        if failSetKeys.contains(name) { return false }
        if value.isEmpty { values.removeValue(forKey: name); return true }
        values[name] = value; return true
    }
    func remove(_ name: String) -> Bool {
        operations.append(.remove(name: name))
        if failRemoveKeys.contains(name) { return false }
        values.removeValue(forKey: name)
        return true
    }
}

final class InstallSessionTests: XCTestCase {
    private var overriddenStorage: FakeTokenStorage?

    override func tearDown() {
        overriddenStorage?.failSetKeys.removeAll()
        overriddenStorage?.failRemoveKeys.removeAll()
        SuperTokens.resetForTests()
        overriddenStorage = nil
        super.tearDown()
    }

    private func encodeFrontToken(_ value: Any) -> String {
        return try! JSONSerialization.data(withJSONObject: value).base64EncodedString()
    }

    // front token = base64(JSON {uid, ate (ms, far future), up})
    private func makeFrontToken(uid: String = "user-a", up: [String: Any] = ["email": "a@example.com"]) -> String {
        return encodeFrontToken(["uid": uid, "ate": Int64(9_999_999_999_999), "up": up])
    }

    private func initAndOverrideStorage(eventHandler: ((EventType) -> Void)? = nil) -> FakeTokenStorage {
        SuperTokens.resetForTests()
        try! SuperTokens.initialize(apiDomain: "https://api.example.com", apiBasePath: "/auth", eventHandler: eventHandler)
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        overriddenStorage = storage
        return storage
    }

    func testInstallSessionWritesAllTokensAndCreatesVisibleSession() {
        let storage = initAndOverrideStorage()
        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                            frontToken: makeFrontToken(), antiCSRFToken: "ACSRF")
        XCTAssertTrue(ok)
        XCTAssertEqual(storage.values[SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)], "AT")
        XCTAssertEqual(storage.values[SDKStorage.genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME)], "RT")
        XCTAssertTrue(SuperTokens.doesSessionExist())
        XCTAssertEqual(SuperTokens.getAccessToken(), "AT")
    }

    func testInstallSessionWithoutAntiCSRFStillCreatesSession() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken(), antiCSRFToken: nil))
        XCTAssertTrue(SuperTokens.doesSessionExist())
    }

    func testInstallSessionRollsBackAndFailsWhenAWriteFails() {
        let storage = initAndOverrideStorage()
        storage.failSetKeys = [SDKStorage.frontTokenKey]        // force the front-token write to fail
        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                            frontToken: makeFrontToken(), antiCSRFToken: "ACSRF")
        XCTAssertFalse(ok)
        XCTAssertFalse(SuperTokens.doesSessionExist())          // fully rolled back, fail closed
        XCTAssertNil(storage.values[SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)])
    }

    func testInstallSessionOverExistingStaleSessionInstallsNewTokens() {
        _ = initAndOverrideStorage()
        // seed an "old" session
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old"), antiCSRFToken: nil))
        XCTAssertEqual(SuperTokens.getAccessToken(), "OLD_AT")
        // install a fresh session for the same user (the magic-link consume)
        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: makeFrontToken(uid: "new"), antiCSRFToken: nil))
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")               // new tokens win
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "new")     // in-memory cache refreshed
    }

    func testClearSessionLocallyRemovesSessionWithoutNetwork() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken(), antiCSRFToken: "ACSRF"))
        XCTAssertTrue(SuperTokens.doesSessionExist())
        XCTAssertTrue(SuperTokens.clearSessionLocally())
        XCTAssertFalse(SuperTokens.doesSessionExist())          // in-memory cache invalidated
        XCTAssertNil(SuperTokens.getAccessToken())
    }

    func testGettersReturnNilBeforeAnySessionExists() {
        _ = initAndOverrideStorage()
        XCTAssertNil(SuperTokens.getRefreshToken())
        XCTAssertNil(SuperTokens.getFrontToken())
        XCTAssertNil(SuperTokens.getAntiCSRF())
    }

    func testGettersReturnRawStoredValuesAfterInstallSession() {
        _ = initAndOverrideStorage()
        let frontToken = makeFrontToken()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: frontToken, antiCSRFToken: "ACSRF"))
        XCTAssertEqual(SuperTokens.getRefreshToken(), "RT")
        XCTAssertEqual(SuperTokens.getFrontToken(), frontToken)
        XCTAssertEqual(SuperTokens.getAntiCSRF(), "ACSRF")
    }

    func testGettersReturnNilAfterClearSessionLocally() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken(), antiCSRFToken: "ACSRF"))
        XCTAssertTrue(SuperTokens.clearSessionLocally())
        XCTAssertNil(SuperTokens.getRefreshToken())
        XCTAssertNil(SuperTokens.getFrontToken())
        XCTAssertNil(SuperTokens.getAntiCSRF())
    }

    func testInstallSessionRejectsMalformedFrontTokenAndWritesNothing() {
        let storage = initAndOverrideStorage()
        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                            frontToken: "not-valid-base64!!", antiCSRFToken: nil)
        XCTAssertFalse(ok)
        XCTAssertFalse(SuperTokens.doesSessionExist())
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testFrontTokenValidationRejectsInvalidClaimTypes() {
        XCTAssertFalse(FrontToken.isWellFormed(encodeFrontToken(["ate": 1, "up": [:]])))
        XCTAssertFalse(FrontToken.isWellFormed(encodeFrontToken(["uid": "user", "ate": true, "up": [:]])))
        XCTAssertFalse(FrontToken.isWellFormed(encodeFrontToken(["uid": "user", "ate": 1.5, "up": [:]])))
        XCTAssertFalse(FrontToken.isWellFormed(encodeFrontToken(["uid": "user", "ate": 1, "up": []])))
    }

    func testInstallSessionRejectsRemoveSentinelAsFrontToken() {
        let storage = initAndOverrideStorage()
        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                            frontToken: "remove", antiCSRFToken: nil)
        XCTAssertFalse(ok)
        XCTAssertFalse(SuperTokens.doesSessionExist())
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testInstallSessionRejectsEmptyAccessToken() {
        let storage = initAndOverrideStorage()
        let ok = SuperTokens.installSession(accessToken: "", refreshToken: "RT",
                                            frontToken: makeFrontToken(), antiCSRFToken: nil)
        XCTAssertFalse(ok)
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testInstallSessionRejectsEmptyRefreshToken() {
        let storage = initAndOverrideStorage()
        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "",
                                            frontToken: makeFrontToken(), antiCSRFToken: nil)
        XCTAssertFalse(ok)
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testInstallSessionFailsBeforeInitializeIsCalled() {
        SuperTokens.resetForTests()
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)

        let ok = SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                            frontToken: makeFrontToken(), antiCSRFToken: nil)
        XCTAssertFalse(ok)
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testInstallSessionClearsStaleAntiCSRFWhenReinstallingWithoutOne() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old"), antiCSRFToken: "OLD_ACSRF"))
        XCTAssertEqual(SuperTokens.getAntiCSRF(), "OLD_ACSRF")

        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: makeFrontToken(uid: "new"), antiCSRFToken: nil))
        XCTAssertNil(SuperTokens.getAntiCSRF())
    }

    func testPayloadUpdateEventCanClearSessionWithoutDeadlock() {
        let callbackCompleted = expectation(description: "payload callback completed")
        let installCompleted = expectation(description: "install completed")
        var clearResult = false
        var shouldClear = false
        _ = initAndOverrideStorage(eventHandler: { event in
            guard case .ACCESS_TOKEN_PAYLOAD_UPDATED = event, shouldClear else { return }
            clearResult = SuperTokens.clearSessionLocally()
            callbackCompleted.fulfill()
        })

        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(up: ["role": "old"])))
        shouldClear = true

        DispatchQueue.global().async {
            XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                     frontToken: self.makeFrontToken(up: ["role": "new"])))
            installCompleted.fulfill()
        }

        wait(for: [callbackCompleted, installCompleted], timeout: 2)
        XCTAssertTrue(clearResult)
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    func testRefreshApplicationCallbackCannotJoinItsOwnRefresh() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken()))
        let callbackCompleted = expectation(description: "nested refresh rejected")
        let sessionSnapshot = SessionStateCoordinator.snapshot { Utils.getLocalSessionState() }
        var status: UnauthorisedResponse.UnauthorisedStatus?

        SuperTokensURLProtocol.runRefreshApplicationCallback {
            SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: sessionSnapshot.value, expectedGeneration: sessionSnapshot.generation) { response in
                status = response.status
                callbackCompleted.fulfill()
            }
        }

        wait(for: [callbackCompleted], timeout: 1)
        XCTAssertEqual(status, .SESSION_EXPIRED)
    }

    func testResponseStartedBeforeInstallCannotOverwriteInstalledSession() {
        _ = initAndOverrideStorage()
        let requestSnapshot = SessionStateCoordinator.requestSnapshot { () }

        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: makeFrontToken(uid: "new")))

        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "STALE_AT",
            "st-refresh-token": "STALE_RT",
            "front-token": makeFrontToken(uid: "stale")
        ])!
        let result = SessionStateCoordinator.applyResponse(expectedGeneration: requestSnapshot.generation, requestSequence: requestSnapshot.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: response)
        }

        guard case .staleGeneration = result else { return XCTFail("Expected generation-stale response") }
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "NEW_RT")
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "new")
    }

    func testResponseStartedBeforeClearCannotRecreateSession() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken()))
        let requestSnapshot = SessionStateCoordinator.requestSnapshot { () }
        XCTAssertTrue(SuperTokens.clearSessionLocally())

        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "STALE_AT",
            "st-refresh-token": "STALE_RT",
            "front-token": makeFrontToken(uid: "stale")
        ])!
        let result = SessionStateCoordinator.applyResponse(expectedGeneration: requestSnapshot.generation, requestSequence: requestSnapshot.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: response)
        }

        guard case .staleGeneration = result else { return XCTFail("Expected generation-stale response") }
        XCTAssertFalse(SuperTokens.doesSessionExist())
        XCTAssertNil(SuperTokens.getRefreshToken())
    }

    func testFailedInstallStillInvalidatesEarlierResponses() {
        let storage = initAndOverrideStorage()
        let requestSnapshot = SessionStateCoordinator.requestSnapshot { () }
        storage.failSetKeys = [SDKStorage.antiCSRFKey]

        XCTAssertFalse(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                  frontToken: makeFrontToken(), antiCSRFToken: "ACSRF"))

        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "STALE_AT",
            "st-refresh-token": "STALE_RT",
            "front-token": makeFrontToken(uid: "stale")
        ])!
        let result = SessionStateCoordinator.applyResponse(expectedGeneration: requestSnapshot.generation, requestSequence: requestSnapshot.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: response)
        }

        guard case .staleGeneration = result else { return XCTFail("Expected generation-stale response") }
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    func testInstallRollbackClosesFrontTokenGateBeforeRemovingTokens() throws {
        let storage = initAndOverrideStorage()
        storage.failSetKeys = [SDKStorage.antiCSRFKey]

        XCTAssertFalse(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                  frontToken: makeFrontToken(), antiCSRFToken: "ACSRF"))

        let failedWrite = try XCTUnwrap(storage.operations.firstIndex(of: .set(name: SDKStorage.antiCSRFKey, value: "ACSRF")))
        let rollback = Array(storage.operations.suffix(from: storage.operations.index(after: failedWrite)))
        let frontTokenRemoval = try XCTUnwrap(rollback.firstIndex(of: .remove(name: SDKStorage.frontTokenKey)))
        let accessTokenRemoval = try XCTUnwrap(rollback.firstIndex(of: .remove(name: SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME))))
        let refreshTokenRemoval = try XCTUnwrap(rollback.firstIndex(of: .remove(name: SDKStorage.genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME))))

        XCTAssertLessThan(frontTokenRemoval, accessTokenRemoval)
        XCTAssertLessThan(frontTokenRemoval, refreshTokenRemoval)
    }

    func testFailedInstallOnlyAttemptsBestEffortRollback() {
        let storage = initAndOverrideStorage()
        storage.failSetKeys = [SDKStorage.antiCSRFKey]
        storage.failRemoveKeys = [SDKStorage.frontTokenKey]
        let frontToken = makeFrontToken()

        XCTAssertFalse(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                   frontToken: frontToken, antiCSRFToken: "ACSRF"))
        XCTAssertEqual(storage.values[SDKStorage.frontTokenKey], frontToken)
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    func testClearInvalidatesFrontTokenCacheWhenALaterRemovalFails() {
        let storage = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken(), antiCSRFToken: "ACSRF"))
        XCTAssertNotNil(FrontToken.tokenInMemory)
        storage.failRemoveKeys = [SDKStorage.genericKey(SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE)]

        XCTAssertFalse(SuperTokens.clearSessionLocally())
        XCTAssertNil(FrontToken.tokenInMemory)
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    func testClearBeforeInitializeReturnsFalseWithoutTouchingStorage() {
        SuperTokens.resetForTests()
        let storage = FakeTokenStorage()
        storage.values[SDKStorage.frontTokenKey] = makeFrontToken()
        SDKStorage.setTokenStorageForTests(storage)

        XCTAssertFalse(SuperTokens.clearSessionLocally())
        XCTAssertTrue(storage.operations.isEmpty)
        XCTAssertNotNil(storage.values[SDKStorage.frontTokenKey])
    }

    func testCurrentResponseAppliesSessionHeaders() {
        _ = initAndOverrideStorage()
        let requestSnapshot = SessionStateCoordinator.requestSnapshot { () }
        let response = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "AT",
            "st-refresh-token": "RT",
            "front-token": makeFrontToken()
        ])!

        let result = SessionStateCoordinator.applyResponse(expectedGeneration: requestSnapshot.generation, requestSequence: requestSnapshot.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: response)
        }

        guard case .applied = result else { return XCTFail("Expected response to apply") }
        XCTAssertEqual(SuperTokens.getAccessToken(), "AT")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "RT")
    }

    func testSessionCreationInvalidatesOlderResponse() {
        _ = initAndOverrideStorage()
        let olderRequest = SessionStateCoordinator.requestSnapshot { () }
        let newerRequest = SessionStateCoordinator.requestSnapshot { () }
        let newerResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "NEW_AT",
            "st-refresh-token": "NEW_RT",
            "front-token": makeFrontToken(uid: "new")
        ])!
        let olderResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "OLD_AT",
            "st-refresh-token": "OLD_RT",
            "front-token": makeFrontToken(uid: "old")
        ])!

        _ = SessionStateCoordinator.applyResponse(expectedGeneration: newerRequest.generation, requestSequence: newerRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: newerResponse)
        }
        let olderResult = SessionStateCoordinator.applyResponse(expectedGeneration: olderRequest.generation, requestSequence: olderRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: olderResponse)
        }

        guard case .staleGeneration = olderResult else { return XCTFail("Expected older response to be generation-stale") }
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "new")
    }

    func testOlderSameUserSessionReplacementSupersedesNewerRefresh() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "A_AT", refreshToken: "A_RT",
                                                 frontToken: makeFrontToken(uid: "a")))
        let replacementRequest = SessionStateCoordinator.requestSnapshot { () }
        let refreshRequest = SessionStateCoordinator.requestSnapshot { () }
        let refreshResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "A_REFRESHED_AT",
            "front-token": makeFrontToken(uid: "a")
        ])!
        let replacementResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "B_AT",
            "st-refresh-token": "B_RT",
            "front-token": makeFrontToken(uid: "a")
        ])!

        let refreshResult = SessionStateCoordinator.applyResponse(expectedGeneration: refreshRequest.generation, requestSequence: refreshRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: refreshResponse)
        }
        guard case .applied = refreshResult else { return XCTFail("Expected refresh response to apply") }

        let replacementResult = SessionStateCoordinator.applyResponse(
            expectedGeneration: replacementRequest.generation,
            requestSequence: replacementRequest.sequence,
            allowOutOfOrder: { Utils.responseStartsNewSession(httpResponse: replacementResponse) }
        ) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: replacementResponse)
        }

        guard case .applied = replacementResult else { return XCTFail("Expected identity replacement to apply") }
        XCTAssertEqual(SuperTokens.getAccessToken(), "B_AT")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "B_RT")
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "a")

        let staleSibling = SessionStateCoordinator.applyResponse(expectedGeneration: refreshRequest.generation, requestSequence: refreshRequest.sequence + 1) {
            SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: false, didMutateSession: false, clearsSession: false)
        }
        guard case .staleGeneration = staleSibling else { return XCTFail("Expected replacement to start a new generation") }
    }

    func testRefreshTokenRotationDoesNotStartNewGeneration() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "a")))
        let refreshRequest = SessionStateCoordinator.requestSnapshot { () }
        let siblingRequest = SessionStateCoordinator.requestSnapshot { () }
        let refreshResponse = HTTPURLResponse(url: URL(string: SuperTokens.refreshTokenUrl)!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "NEW_AT",
            "st-refresh-token": "NEW_RT",
            "front-token": makeFrontToken(uid: "a")
        ])!

        let refreshResult = SessionStateCoordinator.applyResponse(
            expectedGeneration: refreshRequest.generation,
            requestSequence: refreshRequest.sequence,
            allowOutOfOrder: { Utils.responseStartsNewSession(httpResponse: refreshResponse, isRefreshResponse: true) }
        ) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: refreshResponse, isRefreshResponse: true)
        }
        guard case .applied = refreshResult else { return XCTFail("Expected refresh response to apply") }

        let siblingResult = SessionStateCoordinator.applyResponse(expectedGeneration: siblingRequest.generation, requestSequence: siblingRequest.sequence) {
            SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: false, didMutateSession: false, clearsSession: false)
        }
        guard case .applied = siblingResult else { return XCTFail("Expected refresh to retain the current generation") }
        XCTAssertEqual(SuperTokens.getRefreshToken(), "NEW_RT")
    }

    func testFailedResponseInvalidatesSiblingResponses() {
        let storage = initAndOverrideStorage()
        let siblingRequest = SessionStateCoordinator.requestSnapshot { () }
        let failingRequest = SessionStateCoordinator.requestSnapshot { () }
        storage.failSetKeys = [SDKStorage.frontTokenKey]
        let failingResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "FAILED_AT",
            "st-refresh-token": "FAILED_RT",
            "front-token": makeFrontToken(uid: "failed")
        ])!

        let failure = SessionStateCoordinator.applyResponse(expectedGeneration: failingRequest.generation, requestSequence: failingRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: failingResponse)
        }
        guard case .failed = failure else { return XCTFail("Expected response failure") }
        storage.failSetKeys.removeAll()

        let siblingResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "SIBLING_AT",
            "st-refresh-token": "SIBLING_RT",
            "front-token": makeFrontToken(uid: "sibling")
        ])!
        let siblingResult = SessionStateCoordinator.applyResponse(expectedGeneration: siblingRequest.generation, requestSequence: siblingRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: siblingResponse)
        }

        guard case .staleGeneration = siblingResult else { return XCTFail("Expected sibling response to be generation-stale") }
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    func testClearResponseInvalidatesLaterStartedSibling() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT", frontToken: makeFrontToken()))
        let clearRequest = SessionStateCoordinator.requestSnapshot { () }
        let siblingRequest = SessionStateCoordinator.requestSnapshot { () }
        let clearResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "",
            "st-refresh-token": "",
            "front-token": "remove"
        ])!

        let clearResult = SessionStateCoordinator.applyResponse(expectedGeneration: clearRequest.generation, requestSequence: clearRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: clearResponse)
        }
        guard case .applied = clearResult else { return XCTFail("Expected clear response to apply") }

        let siblingResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "STALE_AT",
            "st-refresh-token": "STALE_RT",
            "front-token": makeFrontToken(uid: "stale")
        ])!
        let siblingResult = SessionStateCoordinator.applyResponse(expectedGeneration: siblingRequest.generation, requestSequence: siblingRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: siblingResponse)
        }

        guard case .staleGeneration = siblingResult else { return XCTFail("Expected sibling response to be generation-stale") }
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }

    // A corrupt front token left in storage must not crash the next install: the
    // old-token payload comparison used to force-parse and trap. installSession
    // validates only the incoming token, so a garbage stored value has to be
    // tolerated (and simply overwritten).
    func testInstallSessionOverCorruptStoredFrontTokenDoesNotCrash() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old"), antiCSRFToken: nil))
        // Simulate a corrupted stored front token (e.g. keychain corruption).
        XCTAssertTrue(SDKStorage.set(SDKStorage.frontTokenKey, value: "not-base64-json!!"))
        FrontToken.clearInMemoryCache()                                 // force a reload from storage
        XCTAssertFalse(SuperTokens.doesSessionExist())

        let newFront = makeFrontToken(uid: "new")
        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: newFront, antiCSRFToken: nil))
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
        XCTAssertEqual(SuperTokens.getFrontToken(), newFront)
    }

    func testMalformedResponseFrontTokenWritesNothingAndInvalidatesSiblings() {
        let storage = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old")))
        storage.operations.removeAll()
        let siblingRequest = SessionStateCoordinator.requestSnapshot { () }
        let malformedRequest = SessionStateCoordinator.requestSnapshot { () }
        let malformedResponse = HTTPURLResponse(url: URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "BAD_AT",
            "st-refresh-token": "BAD_RT",
            "front-token": "not-valid-base64!!"
        ])!

        let malformedResult = SessionStateCoordinator.applyResponse(expectedGeneration: malformedRequest.generation, requestSequence: malformedRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: malformedResponse)
        }

        guard case .failed = malformedResult else { return XCTFail("Expected malformed response to fail") }
        XCTAssertTrue(storage.operations.isEmpty)
        XCTAssertEqual(SuperTokens.getAccessToken(), "OLD_AT")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "OLD_RT")

        var siblingWriteExecuted = false
        let siblingResult = SessionStateCoordinator.applyResponse(expectedGeneration: siblingRequest.generation, requestSequence: siblingRequest.sequence) {
            siblingWriteExecuted = true
            return SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: false)
        }
        guard case .staleGeneration = siblingResult else { return XCTFail("Expected sibling response to be generation-stale") }
        XCTAssertFalse(siblingWriteExecuted)
    }

    func testGenerationStale401DoesNotRetryAgainstReplacementSession() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old")))
        let unexpectedRetry = expectation(description: "old request was retried")
        unexpectedRetry.isInverted = true
        var requestCount = 0
        var firstCompletion: SuperTokensURLProtocol.NetworkCompletion?
        SuperTokensURLProtocol.networkRequestExecutor = { _, completion in
            requestCount += 1
            if requestCount == 1 {
                firstCompletion = completion
            } else {
                unexpectedRetry.fulfill()
            }
        }

        var request = URLRequest(url: URL(string: "https://api.example.com/auth/signout")!)
        request.httpMethod = "POST"
        let urlProtocol = SuperTokensURLProtocol(request: request, cachedResponse: nil, client: nil)
        urlProtocol.makeRequest()
        XCTAssertEqual(requestCount, 1)

        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: makeFrontToken(uid: "new")))
        firstCompletion?(nil, HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil), nil)

        wait(for: [unexpectedRetry], timeout: 0.2)
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
        XCTAssertEqual(SuperTokens.getRefreshToken(), "NEW_RT")
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "new")
    }

    func testRetryGenerationGuardRejectsLateReplacement() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "OLD_RT",
                                                 frontToken: makeFrontToken(uid: "old")))
        let originatingGeneration = SessionStateCoordinator.snapshot { () }.generation
        XCTAssertTrue(SuperTokens.installSession(accessToken: "NEW_AT", refreshToken: "NEW_RT",
                                                 frontToken: makeFrontToken(uid: "new")))
        var requestExecuted = false
        var generationChangeHandled = false
        let urlProtocol = SuperTokensURLProtocol(request: URLRequest(url: URL(string: "https://api.example.com/protected")!), cachedResponse: nil, client: nil)

        urlProtocol.makeRequest(
            networkRequestExecutor: { _, _ in requestExecuted = true },
            expectedGeneration: originatingGeneration,
            onGenerationChange: { generationChangeHandled = true }
        )

        XCTAssertFalse(requestExecuted)
        XCTAssertTrue(generationChangeHandled)
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
    }

    func testOutOfOrder401RetriesWithCurrentSession() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "OLD_AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken(uid: "old")))
        let retried = expectation(description: "out-of-order request retried")
        var requests: [URLRequest] = []
        var firstCompletion: SuperTokensURLProtocol.NetworkCompletion?
        SuperTokensURLProtocol.networkRequestExecutor = { request, completion in
            requests.append(request)
            if requests.count == 1 {
                firstCompletion = completion
            } else {
                retried.fulfill()
            }
        }

        let request = URLRequest(url: URL(string: "https://api.example.com/protected")!)
        let urlProtocol = SuperTokensURLProtocol(request: request, cachedResponse: nil, client: nil)
        urlProtocol.makeRequest()
        let newerRequest = SessionStateCoordinator.requestSnapshot { () }
        let newerResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-access-token": "NEW_AT",
            "front-token": makeFrontToken(uid: "old")
        ])!
        let newerResult = SessionStateCoordinator.applyResponse(expectedGeneration: newerRequest.generation, requestSequence: newerRequest.sequence) {
            Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: newerResponse)
        }
        guard case .applied = newerResult else { return XCTFail("Expected newer response to apply") }

        firstCompletion?(nil, HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil), nil)

        wait(for: [retried], timeout: 1)
        XCTAssertEqual(requests.count, 2)
        guard requests.count == 2 else { return }
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer NEW_AT")
    }

    func testReplacementSessionStartsIndependentRefreshCohort() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "A_AT", refreshToken: "A_RT",
                                                 frontToken: makeFrontToken(uid: "a")))
        let firstRefreshStarted = expectation(description: "first refresh started")
        let secondRefreshStarted = expectation(description: "replacement refresh started")
        let firstCallbackCompleted = expectation(description: "first callback completed")
        let secondCallbackCompleted = expectation(description: "second callback completed")
        var completions: [SuperTokensURLProtocol.NetworkCompletion] = []
        SuperTokensURLProtocol.networkRequestExecutor = { _, completion in
            completions.append(completion)
            if completions.count == 1 {
                firstRefreshStarted.fulfill()
            } else {
                secondRefreshStarted.fulfill()
            }
        }

        let firstSnapshot = SessionStateCoordinator.snapshot { Utils.getLocalSessionState() }
        var firstStatus: UnauthorisedResponse.UnauthorisedStatus?
        SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: firstSnapshot.value, expectedGeneration: firstSnapshot.generation) { response in
            firstStatus = response.status
            firstCallbackCompleted.fulfill()
        }
        wait(for: [firstRefreshStarted], timeout: 1)

        XCTAssertTrue(SuperTokens.installSession(accessToken: "B_AT", refreshToken: "B_RT",
                                                 frontToken: makeFrontToken(uid: "b")))
        let secondSnapshot = SessionStateCoordinator.snapshot { Utils.getLocalSessionState() }
        var secondStatus: UnauthorisedResponse.UnauthorisedStatus?
        SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: secondSnapshot.value, expectedGeneration: secondSnapshot.generation) { response in
            secondStatus = response.status
            secondCallbackCompleted.fulfill()
        }
        wait(for: [firstCallbackCompleted, secondRefreshStarted], timeout: 1)
        XCTAssertEqual(firstStatus, .SESSION_EXPIRED)
        XCTAssertEqual(completions.count, 2)

        let refreshURL = URL(string: "https://api.example.com/auth/session/refresh")!
        completions[0](nil, HTTPURLResponse(url: refreshURL, statusCode: 500, httpVersion: nil, headerFields: nil), nil)
        completions[1](nil, HTTPURLResponse(url: refreshURL, statusCode: 500, httpVersion: nil, headerFields: nil), nil)
        wait(for: [secondCallbackCompleted], timeout: 1)
        XCTAssertEqual(secondStatus, .API_ERROR)
        XCTAssertEqual(SuperTokens.getAccessToken(), "B_AT")
    }

    func testSignOutCompletesExactlyOnceOnTerminal401() {
        _ = initAndOverrideStorage()
        XCTAssertTrue(SuperTokens.installSession(accessToken: "AT", refreshToken: "RT",
                                                 frontToken: makeFrontToken()))
        SuperTokens.signOutRequestExecutor = { request, completion in
            completion(nil, HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil), nil)
        }
        var completionCount = 0
        var completionError: Error?

        SuperTokens.signOut { error in
            completionCount += 1
            completionError = error
        }

        XCTAssertEqual(completionCount, 1)
        XCTAssertNil(completionError)
    }
}
