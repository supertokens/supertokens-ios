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
    // front token = base64(JSON {uid, ate (ms, far future), up})
    private func makeFrontToken(uid: String = "user-a", up: [String: Any] = ["email": "a@example.com"]) -> String {
        let json = try! JSONSerialization.data(withJSONObject: ["uid": uid, "ate": Int64(9_999_999_999_999), "up": up])
        return json.base64EncodedString()
    }

    private func initAndOverrideStorage(eventHandler: ((EventType) -> Void)? = nil) -> FakeTokenStorage {
        SuperTokens.resetForTests()
        try! SuperTokens.initialize(apiDomain: "https://api.example.com", apiBasePath: "/auth", eventHandler: eventHandler)
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
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
        let localSessionState = Utils.getLocalSessionState()
        var status: UnauthorisedResponse.UnauthorisedStatus?

        SuperTokensURLProtocol.runRefreshApplicationCallback {
            SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: localSessionState) { response in
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

        guard case .stale = result else { return XCTFail("Expected stale response") }
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

        guard case .stale = result else { return XCTFail("Expected stale response") }
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

        guard case .stale = result else { return XCTFail("Expected stale response") }
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

    func testOlderResponseCannotOverwriteNewerResponse() {
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

        guard case .stale = olderResult else { return XCTFail("Expected older response to be stale") }
        XCTAssertEqual(SuperTokens.getAccessToken(), "NEW_AT")
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "new")
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

        guard case .stale = siblingResult else { return XCTFail("Expected sibling response to be stale") }
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

        guard case .stale = siblingResult else { return XCTFail("Expected sibling response to be stale") }
        XCTAssertFalse(SuperTokens.doesSessionExist())
    }
}
