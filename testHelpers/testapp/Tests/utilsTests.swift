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
}
