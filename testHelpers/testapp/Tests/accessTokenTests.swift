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

class accessTokenTests: XCTestCase {
    let fakeGetApi = "https://www.google.com"
    let refreshCustomHeader = "\(testAPIBase)/refreshHeader"

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
    
    // MARK: Tests
    func testThatAppropriateAccessTokenPayloadIsReturned() {
        TestUtils.startST(validity: 3)
        
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase)
        } catch {
            XCTFail()
        }
        
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
                data, response, error in

                if error != nil {
                    XCTFail("Login request failed")
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail()
                    }
                    
                    requestSemaphore.signal()
                } else {
                    XCTFail("Login API responded with non 200 status")
                    requestSemaphore.signal()
                }
            }).resume()

            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            
            var payload = try! SuperTokens.getAccessTokenPayloadSecurely()
            
            if try! TestUtils.checkIfV3AccessTokenIsSupported() {
                var expectedKeys = [
                    "sub",
                    "exp",
                    "iat",
                    "sessionHandle",
                    "refreshTokenHash1",
                    "parentRefreshTokenHash1",
                    "antiCsrfToken",
                    "iss"
                ]
                
                if payload.contains(where: {
                    key, _ in
                    
                    return key == "tId"
                }) {
                    expectedKeys.append("tId")
                }
                
                if payload.contains(where: {
                    key, _ in
                    
                    return key == "rsub"
                }) {
                    expectedKeys.append("rsub")
                }
                
                XCTAssert(payload.count == expectedKeys.count)
                for (key, _) in payload {
                    XCTAssert(expectedKeys.contains(key))
                }
            } else {
                XCTAssert(payload.count == 0)
            }
        }
    }
    
    func testThatASessionCreatedWithCDI_2_18_CanBeRefreshed() {
        TestUtils.startST(validity: 3)
        
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase)
        } catch {
            XCTFail()
        }
        
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: TestUtils.getLoginRequest_2_18(), completionHandler: {
                data, response, error in

                if error != nil {
                    XCTFail("Login request failed")
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail()
                    }
                    
                    requestSemaphore.signal()
                } else {
                    XCTFail("Login API responded with non 200 status")
                    requestSemaphore.signal()
                }
            }).resume()

            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            
            var payload218 = try! SuperTokens.getAccessTokenPayloadSecurely()
            
            XCTAssert(payload218.count == 1)
            XCTAssert((payload218["asdf"] as! Int) == 1)
            
            _ = try! SuperTokens.attemptRefreshingSession()
            
            if try! TestUtils.checkIfV3AccessTokenIsSupported() {
                let v3Payload = try! SuperTokens.getAccessTokenPayloadSecurely()
                
                var expectedKeys = [
                    "sub",
                    "exp",
                    "iat",
                    "sessionHandle",
                    "refreshTokenHash1",
                    "parentRefreshTokenHash1",
                    "antiCsrfToken",
                    "asdf"
                ]
                
                if v3Payload.contains(where: {
                    key, _ in
                    
                    return key == "tId"
                }) {
                    expectedKeys.append("tId")
                }
                
                if v3Payload.contains(where: {
                    key, _ in
                    
                    return key == "rsub"
                }) {
                    expectedKeys.append("rsub")
                }
                
                XCTAssert(v3Payload.count == expectedKeys.count)
                for (key, _) in v3Payload {
                    XCTAssert(expectedKeys.contains(key))
                }
            } else {
                let v2Payload = try! SuperTokens.getAccessTokenPayloadSecurely()
                
                XCTAssert(v2Payload.count == 1)
                XCTAssert((v2Payload["asdf"] as! Int) == 1)
            }
        }
    }
}
