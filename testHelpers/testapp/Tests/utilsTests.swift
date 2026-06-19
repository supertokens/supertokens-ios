/* Copyright (c) 2020, VRAI Labs and/or its affiliates. All rights reserved.
 *
 * This software is licensed under the Apache License, Version 2.0 (the
 * "License") as published by the Apache Software Foundation.
 *
 * You may not use this file except in compliance with the License. You may
 * obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

import XCTest
import Security
@testable import SuperTokensIOS

private class FakeTokenStorage: TokenStorage {
    var values: [String: String] = [:]
    var failSetKeys: Set<String> = []
    var failRemoveKeys: Set<String> = []
    var removedKeys: [String] = []

    func get(_ name: String) -> String? {
        return values[name]
    }

    func set(_ name: String, value: String) -> Bool {
        if failSetKeys.contains(name) {
            return false
        }

        values[name] = value
        return true
    }

    func remove(_ name: String) -> Bool {
        removedKeys.append(name)

        if failRemoveKeys.contains(name) {
            return false
        }

        values.removeValue(forKey: name)
        return true
    }
}

private class DuplicateOnAddKeychainClient: KeychainClient {
    private(set) var updateCalls = 0
    private(set) var addCalls = 0

    func get(_ query: [String: Any]) -> (status: OSStatus, data: Data?) {
        return (errSecItemNotFound, nil)
    }

    func set(_ query: [String: Any]) -> OSStatus {
        addCalls += 1
        return errSecDuplicateItem
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        updateCalls += 1
        return updateCalls == 1 ? errSecItemNotFound : errSecSuccess
    }

    func remove(_ query: [String: Any]) -> OSStatus {
        return errSecSuccess
    }
}

private class CapturingKeychainClient: KeychainClient {
    private(set) var lastSetQuery: [String: Any]?

    func get(_ query: [String: Any]) -> (status: OSStatus, data: Data?) {
        return (errSecItemNotFound, nil)
    }

    func set(_ query: [String: Any]) -> OSStatus {
        lastSetQuery = query
        return errSecSuccess
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        return errSecItemNotFound
    }

    func remove(_ query: [String: Any]) -> OSStatus {
        return errSecSuccess
    }
}

class utilsTest: XCTestCase {
    let fakeGetApi = "https://www.google.com"
    
    // MARK: Runs after all tests
    override class func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)

        TestUtils.afterAllTests {
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        super.tearDown()
    }
    
    // MARK: Runs after each test
    override func tearDown() {
        URLProtocol.unregisterClass(SuperTokensURLProtocol.self)
        SDKStorage.configure(userDefaultsSuiteName: nil, keychainAccessGroup: nil)
        SDKStorage.clearSessionStorage()
        super.tearDown()
    }
    
    // MARK: Runs before all tests
    override class func setUp() {
        super.setUp()
        
        let semaphore = DispatchSemaphore(value: 0)
        
        TestUtils.beforeAllTests {
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // MARK: Runs before each test
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let semaphore = DispatchSemaphore(value: 0)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        
        TestUtils.beforeEachTest {
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        URLProtocol.registerClass(SuperTokensURLProtocol.self)
    }
    
    func testThatDictionaryLowerCaseExtensionWorksFine() {
         var dict: Dictionary = [
            "key": "value",
            "CasedKey": "CasedValue",
            "WeiRDcaSedKey": "weiRdcasedValUe"
        ]
        
        dict.lowerCaseKeys()
        
        XCTAssert(dict["key"] == "value")
        XCTAssert(dict["casedkey"] == "CasedValue")
        XCTAssert(dict["weirdcasedkey"] == "weiRdcasedValUe")
        
        func dictContainsKey(_ key: String) -> Bool {
            return dict.contains(where: {
                _key, _ in
                
                return _key == key
            })
        }
        
        XCTAssert(dictContainsKey("key"))
        XCTAssert(!dictContainsKey("CasedKey"))
        XCTAssert(!dictContainsKey("WeiRDcaSedKey"))
    }
    
    func testThatSavingHeadersFromResponseIsCaseInsensitive() {
        var httpResonse = HTTPURLResponse(url: URL(string: fakeGetApi)!, statusCode: 200, httpVersion: nil, headerFields: [
            "St-Access-Token": "access-token",
            "ST-refresh-TOKEN": "refresh-token",
        ])
        
        XCTAssertTrue(Utils.saveTokenFromHeaders(httpResponse: httpResonse!))
        
        let accessToken = Utils.getTokenForHeaderAuth(tokenType: .access)
        let refreshToken = Utils.getTokenForHeaderAuth(tokenType: .refresh)
        
        XCTAssert(accessToken == "access-token")
        XCTAssert(refreshToken == "refresh-token")
    }

    private func makeFrontToken(uid: String = "user-id", up: [String: Any] = [:], ate: Int64 = 9999999999999) -> String {
        let payload: [String: Any] = [
            "uid": uid,
            "ate": ate,
            "up": up
        ]

        return try! JSONSerialization.data(withJSONObject: payload).base64EncodedString()
    }

    private func sessionStorageKeys() -> [String] {
        return [
            SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME),
            SDKStorage.genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME),
            SDKStorage.genericKey(SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE),
            SDKStorage.genericKey("sIRTFrontend"),
            SDKStorage.frontTokenKey,
            SDKStorage.antiCSRFKey
        ]
    }

    private func assertNoSessionValues(_ storage: FakeTokenStorage, file: StaticString = #filePath, line: UInt = #line) {
        for key in sessionStorageKeys() {
            XCTAssertNil(storage.values[key], "Expected \(key) to be cleared", file: file, line: line)
            XCTAssertNil(Utils.getUserDefaults().string(forKey: key), "Expected legacy \(key) to be cleared", file: file, line: line)
        }

        XCTAssertFalse(FrontToken.doesTokenExist(), file: file, line: line)
        XCTAssertEqual(Utils.getLocalSessionState().status, .NOT_EXISTS, file: file, line: line)
    }

    func testLegacyGenericStorageMigratesToKeychainOnRead() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let key = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)
        Utils.getUserDefaults().set("legacy-access-token", forKey: key)

        XCTAssertEqual(Utils.getTokenForHeaderAuth(tokenType: .access), "legacy-access-token")
        XCTAssertEqual(storage.values[key], "legacy-access-token")
        XCTAssertNil(Utils.getUserDefaults().string(forKey: key))
    }

    func testLegacyGenericStorageIsKeptIfMigrationWriteFails() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let key = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)
        storage.failSetKeys.insert(key)
        Utils.getUserDefaults().set("legacy-access-token", forKey: key)

        XCTAssertNil(Utils.getTokenForHeaderAuth(tokenType: .access))
        XCTAssertEqual(Utils.getUserDefaults().string(forKey: key), "legacy-access-token")
    }

    func testLegacyFrontTokenMigratesToTokenStorageOnRead() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let frontToken = makeFrontToken(uid: "legacy-user")
        Utils.getUserDefaults().set(frontToken, forKey: SDKStorage.frontTokenKey)
        XCTAssertTrue(Utils.saveLastAccessTokenUpdate())

        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "legacy-user")
        XCTAssertEqual(storage.values[SDKStorage.frontTokenKey], frontToken)
        XCTAssertNil(Utils.getUserDefaults().string(forKey: SDKStorage.frontTokenKey))
    }

    func testLegacyAntiCSRFMigratesToTokenStorageOnRead() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        Utils.getUserDefaults().set("legacy-csrf", forKey: SDKStorage.antiCSRFKey)

        XCTAssertEqual(AntiCSRF.getToken(associatedAccessTokenUpdate: "update-id"), "legacy-csrf")
        XCTAssertEqual(storage.values[SDKStorage.antiCSRFKey], "legacy-csrf")
        XCTAssertNil(Utils.getUserDefaults().string(forKey: SDKStorage.antiCSRFKey))
    }

    func testClearSessionStorageReturnsFalseAndKeepsCachesWhenSecureDeleteFails() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let frontToken = makeFrontToken()
        XCTAssertTrue(FrontToken.setItem(frontToken: frontToken))
        let lastAccessTokenUpdate = Utils.getFromStorage(name: SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE)!
        XCTAssertTrue(AntiCSRF.setToken(antiCSRFToken: "csrf-token", associatedAccessTokenUpdate: lastAccessTokenUpdate))
        storage.failRemoveKeys = Set(sessionStorageKeys())

        XCTAssertFalse(SDKStorage.clearSessionStorage())
        XCTAssertEqual(storage.values[SDKStorage.frontTokenKey], frontToken)
        XCTAssertTrue(FrontToken.doesTokenExist())
        XCTAssertEqual(AntiCSRF.getToken(associatedAccessTokenUpdate: lastAccessTokenUpdate), "csrf-token")
    }

    func testFrontTokenRemoveReturnsFalseWhenSecureDeleteFails() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let frontToken = makeFrontToken()
        XCTAssertTrue(FrontToken.setItem(frontToken: frontToken))
        storage.failRemoveKeys = Set(sessionStorageKeys())

        XCTAssertFalse(FrontToken.removeToken())
        XCTAssertEqual(storage.values[SDKStorage.frontTokenKey], frontToken)
        XCTAssertTrue(FrontToken.doesTokenExist())
    }

    func testFrontTokenRemoveClearsSessionMetadata() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        XCTAssertTrue(FrontToken.setItem(frontToken: makeFrontToken()))

        XCTAssertTrue(FrontToken.removeToken())

        assertNoSessionValues(storage)
    }

    func testKeychainTokenStorageRetriesUpdateWhenAddFindsDuplicateItem() {
        let keychain = DuplicateOnAddKeychainClient()
        let storage = KeychainTokenStorage(service: "io.supertokens.test.duplicate", keychain: keychain)

        XCTAssertTrue(storage.set("token", value: "value"))
        XCTAssertEqual(keychain.addCalls, 1)
        XCTAssertEqual(keychain.updateCalls, 2)
    }

    func testKeychainTokenStorageUsesWhenUnlockedAccessibilityByDefault() {
        let keychain = CapturingKeychainClient()
        let storage = KeychainTokenStorage(service: "io.supertokens.test.accessibility", keychain: keychain)

        XCTAssertTrue(storage.set("token", value: "value"))
        XCTAssertEqual(keychain.lastSetQuery?[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    func testConfiguredUserDefaultsSuiteDoesNotChangeActiveKeychainService() {
        let suiteA = "io.supertokens.tests.a.\(UUID().uuidString)"
        let suiteB = "io.supertokens.tests.b.\(UUID().uuidString)"
        let key = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)

        SDKStorage.configure(userDefaultsSuiteName: suiteA, keychainAccessGroup: nil)
        XCTAssertTrue(SDKStorage.set(key, value: "suite-a-token"))

        SDKStorage.configure(userDefaultsSuiteName: suiteB, keychainAccessGroup: nil)
        XCTAssertEqual(SDKStorage.get(key), "suite-a-token")
        XCTAssertTrue(SDKStorage.remove(key))
    }

    func testDifferentApiConfigsUseSeparateKeychainServices() {
        let key = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)

        SDKStorage.configure(userDefaultsSuiteName: nil, keychainAccessGroup: nil, apiDomain: "https://api-a.example.com", apiBasePath: "/auth")
        XCTAssertTrue(SDKStorage.set(key, value: "api-a-token"))

        SDKStorage.configure(userDefaultsSuiteName: nil, keychainAccessGroup: nil, apiDomain: "https://api-b.example.com", apiBasePath: "/auth")
        XCTAssertNil(SDKStorage.get(key))

        SDKStorage.configure(userDefaultsSuiteName: nil, keychainAccessGroup: nil, apiDomain: "https://api-a.example.com", apiBasePath: "/auth")
        XCTAssertEqual(SDKStorage.get(key), "api-a-token")
        XCTAssertTrue(SDKStorage.remove(key))
    }

    func testLegacyStorageMigrationUsesConfiguredUserDefaultsSuite() throws {
        let suiteName = "io.supertokens.tests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let storage = FakeTokenStorage()
        try SuperTokens.initialize(apiDomain: fakeGetApi, userDefaultsSuiteName: suiteName)
        SDKStorage.setTokenStorageForTests(storage)
        let key = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)
        suite.set("legacy-access-token", forKey: key)

        XCTAssertEqual(Utils.getTokenForHeaderAuth(tokenType: .access), "legacy-access-token")
        XCTAssertEqual(storage.values[key], "legacy-access-token")
        XCTAssertNil(suite.string(forKey: key))
        suite.removePersistentDomain(forName: suiteName)
    }

    func testFrontTokenIsWrittenToTokenStorage() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let frontToken = makeFrontToken()

        XCTAssertTrue(FrontToken.setItem(frontToken: frontToken))
        XCTAssertEqual(storage.values[SDKStorage.frontTokenKey], frontToken)
        XCTAssertEqual(FrontToken.getToken()?["uid"] as? String, "user-id")
    }

    func testAntiCSRFTokenIsWrittenToTokenStorage() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)

        XCTAssertTrue(AntiCSRF.setToken(antiCSRFToken: "csrf-token", associatedAccessTokenUpdate: "update-id"))
        XCTAssertEqual(storage.values[SDKStorage.antiCSRFKey], "csrf-token")
        XCTAssertEqual(AntiCSRF.getToken(associatedAccessTokenUpdate: "update-id"), "csrf-token")
    }

    func testFailedHeaderTokenWriteClearsPartiallyWrittenSessionStorage() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let accessTokenKey = SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)
        let refreshTokenKey = SDKStorage.genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME)
        storage.failSetKeys.insert(accessTokenKey)
        let httpResponse = HTTPURLResponse(url: URL(string: fakeGetApi)!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-refresh-token": "refresh-token",
            "st-access-token": "access-token"
        ])!

        XCTAssertFalse(Utils.saveTokenFromHeaders(httpResponse: httpResponse))

        XCTAssertNil(storage.values[refreshTokenKey])
        XCTAssertNil(Utils.getTokenForHeaderAuth(tokenType: .refresh))
        XCTAssertNil(Utils.getTokenForHeaderAuth(tokenType: .access))
    }

    func testHeaderSaveClearsAllSessionStorageWhenFrontTokenWriteFails() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        storage.failSetKeys.insert(SDKStorage.frontTokenKey)
        let httpResponse = HTTPURLResponse(url: URL(string: fakeGetApi)!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-refresh-token": "refresh-token",
            "st-access-token": "access-token",
            "front-token": makeFrontToken()
        ])!

        XCTAssertFalse(Utils.saveTokenFromHeaders(httpResponse: httpResponse))

        assertNoSessionValues(storage)
    }

    func testHeaderSaveClearsAllSessionStorageWhenAntiCSRFWriteFails() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        storage.failSetKeys.insert(SDKStorage.antiCSRFKey)
        let httpResponse = HTTPURLResponse(url: URL(string: fakeGetApi)!, statusCode: 200, httpVersion: nil, headerFields: [
            "st-refresh-token": "refresh-token",
            "st-access-token": "access-token",
            "front-token": makeFrontToken(),
            "anti-csrf": "csrf-token"
        ])!

        XCTAssertFalse(Utils.saveTokenFromHeaders(httpResponse: httpResponse))

        assertNoSessionValues(storage)
    }

    func testFrontTokenPayloadUpdateEventIsNotEmittedWhenStorageWriteFails() throws {
        let storage = FakeTokenStorage()
        var payloadUpdateEvents = 0
        try SuperTokens.initialize(apiDomain: fakeGetApi, eventHandler: { event in
            if event == .ACCESS_TOKEN_PAYLOAD_UPDATED {
                payloadUpdateEvents += 1
            }
        })
        SDKStorage.setTokenStorageForTests(storage)

        XCTAssertTrue(FrontToken.setItem(frontToken: makeFrontToken(up: ["role": "old"])))
        storage.failSetKeys.insert(SDKStorage.frontTokenKey)

        XCTAssertFalse(FrontToken.setItem(frontToken: makeFrontToken(up: ["role": "new"])))
        XCTAssertEqual(payloadUpdateEvents, 0)
        assertNoSessionValues(storage)
    }
}
