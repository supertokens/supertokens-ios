import XCTest
@testable import SuperTokensIOS

private final class FakeTokenStorage: TokenStorage {
    var values: [String: String] = [:]
    var failSetKeys: Set<String> = []
    func get(_ name: String) -> String? { values[name] }
    func set(_ name: String, value: String) -> Bool {
        if failSetKeys.contains(name) { return false }
        if value.isEmpty { values.removeValue(forKey: name); return true }
        values[name] = value; return true
    }
    func remove(_ name: String) -> Bool { values.removeValue(forKey: name); return true }
}

final class InstallSessionTests: XCTestCase {
    // front token = base64(JSON {uid, ate (ms, far future), up})
    private func makeFrontToken(uid: String = "user-a", up: [String: Any] = ["email": "a@example.com"]) -> String {
        let ate = Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
        let json = try! JSONSerialization.data(withJSONObject: ["uid": uid, "ate": ate, "up": up])
        return json.base64EncodedString()
    }

    private func initAndOverrideStorage() -> FakeTokenStorage {
        SuperTokens.resetForTests()
        try! SuperTokens.initialize(apiDomain: "https://api.example.com", apiBasePath: "/auth")
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
}
