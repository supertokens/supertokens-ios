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
@testable import SuperTokensIOS

private class FakeTokenStorage: TokenStorage {
    var values: [String: String] = [:]
    var failSetKeys: Set<String> = []

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
        values.removeValue(forKey: name)
        return true
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
        SDKStorage.configure(keychainAccessGroup: nil)
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
        
        Utils.saveTokenFromHeaders(httpResponse: httpResonse!)
        
        let accessToken = Utils.getTokenForHeaderAuth(tokenType: .access)
        let refreshToken = Utils.getTokenForHeaderAuth(tokenType: .refresh)
        
        XCTAssert(accessToken == "access-token")
        XCTAssert(refreshToken == "refresh-token")
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

    func testFrontTokenIsWrittenToTokenStorage() {
        let storage = FakeTokenStorage()
        SDKStorage.setTokenStorageForTests(storage)
        let frontToken = Data("{\"uid\":\"user-id\",\"ate\":9999999999999,\"up\":{}}".utf8).base64EncodedString()

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

        Utils.saveTokenFromHeaders(httpResponse: httpResponse)

        XCTAssertNil(storage.values[refreshTokenKey])
        XCTAssertNil(Utils.getTokenForHeaderAuth(tokenType: .refresh))
        XCTAssertNil(Utils.getTokenForHeaderAuth(tokenType: .access))
    }
}
