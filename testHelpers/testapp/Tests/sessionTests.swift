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

/* TODO:
 - Proper change in anti-csrf token once access token resets
 - User passed config should be sent as well
 */

class sessionTests: XCTestCase {
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

    /**
     Test that if you are logged out and you call an API that requires sessions,
     you get session expired output and that refresh token API doesnt get called
     */
    func testSessionExpiredErrorAndNoRefreshToken() {
        TestUtils.startST(validity: 3)

        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            XCTFail()
        }

        do {
            let userInfoURL = URL(string: "\(testAPIBase)/")
            let userInfoRequest = URLRequest(url: userInfoURL!)
            let requestSemaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
                userInfoData, userInfoResponse, userInfoError in

                if userInfoError != nil {
                    XCTFail("API failed when unexpected error")
                    requestSemaphore.signal()
                    return
                }

                if userInfoResponse as? HTTPURLResponse != nil {
                    let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                    if userInfoHttpResponse.statusCode != 401 {
                        XCTFail("API should have returned unauthorised but didnt")
                    }
                    requestSemaphore.signal()
                } else {
                    XCTFail("API returned invalid response")
                    requestSemaphore.signal()
                }
            }).resume()

            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }

        let counter = TestUtils.getRefreshTokenCounter()
        if (counter != 0) {
            XCTFail("Refresh counter returned non zero value")
        }
    }
//
    // Things should work if anti-csrf is disabled.
    func testThingsWorkIfAntiCSRFIsDisabled() {
        TestUtils.startST(validity: 3, disableAntiCSRF: true)

        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
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
                        requestSemaphore.signal()
                    } else {
                        let userInfoURL = URL(string: "\(testAPIBase)/")
                        let userInfoRequest = URLRequest(url: userInfoURL!)

                        sleep(5)

                        URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
                            userInfoData, userInfoResponse, userInfoError in

                            if userInfoError != nil {
                                XCTFail("API failed")
                                requestSemaphore.signal()
                                return
                            }

                            if userInfoResponse as? HTTPURLResponse != nil {
                                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                                if userInfoHttpResponse.statusCode != 200 {
                                    XCTFail("API responded with status \(userInfoHttpResponse.statusCode)")
                                }
                                requestSemaphore.signal()
                            } else {
                                XCTFail("Invalid API response")
                                requestSemaphore.signal()
                            }
                        }).resume()
                    }
                } else {
                    XCTFail("Login API responded with non 200 status")
                    requestSemaphore.signal()
                }
            }).resume()

            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }

        let counter = TestUtils.getRefreshTokenCounter()
        if (counter != 1) {
            XCTFail("Refresh counter returned wrong value")
        }

        // logout
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: "\(testAPIBase)/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            URLSession.shared.dataTask(with: request, completionHandler: {
                data, response, error in
                if error != nil {
                    XCTFail("logout Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("logout Api Error")
                        requestSemaphore.signal()
                        return
                    }
                }
                requestSemaphore.signal()
            }).resume()
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            XCTAssertTrue(!SuperTokens.doesSessionExist())
        }
    }

//    // Custom refresh API headers are going through
    func testCustomHeadersForRefreshAPI() {
        TestUtils.startST(validity: 3)

        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie, preAPIHook: {
                action, request in

                let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

                if action == .REFRESH_SESSION {
                    mutableRequest.addValue("custom-value", forHTTPHeaderField: "custom-header")
                }

                return mutableRequest.copy() as! URLRequest
            })
        } catch {
            XCTFail("Init failed")
        }

        do {
            let requestSemaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
                data, response, error in

                if error != nil {
                    XCTFail("login API error")
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("http response code is not 200");
                        requestSemaphore.signal()
                    } else {
                        sleep(5)
                        let userInfoURL = URL(string: "\(testAPIBase)/")
                        let userInfoRequest = URLRequest(url: userInfoURL!)

                        URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
                            userInfoData, userInfoResponse, userInfoError in

                            if userInfoError != nil {
                                XCTFail("userInfo API error")
                                requestSemaphore.signal()
                                return
                            }

                            if userInfoResponse as? HTTPURLResponse != nil {
                                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                                if userInfoHttpResponse.statusCode != 200 {
                                    XCTFail("userInfo API non 200 HTTP status code")
                                }
                                requestSemaphore.signal()
                            } else {
                                XCTFail("userInfo API response is nil")
                                requestSemaphore.signal()
                            }
                        }).resume()
                    }
                } else {
                    XCTFail("http response is nil");
                    requestSemaphore.signal()
                }
            }).resume()
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }

        do  {
            let url = URL(string: refreshCustomHeader)
            var request = URLRequest(url: url!)
            let requestSemaphore = DispatchSemaphore(value: 0)

            URLSession.shared.dataTask(with: request, completionHandler: {
                data, response, error in

                if error != nil {
                    XCTFail("Error")
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    do {
                        let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
                        let value = jsonResponse.value(forKey: "value") as? String
                        if value != "custom-value" {
                            XCTFail("header not sent.");
                        }
                    } catch {
                        XCTFail("some error");
                    }
                    requestSemaphore.signal()
                } else {
                    XCTFail("http response is nil");
                    requestSemaphore.signal()
                }
            }).resume()

            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }

    func testThatInterceptorIsntUsedWithoutCallingInit() {
        TestUtils.startST(validity: 3)
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in

            if error != nil {
                XCTFail("Login failed")
            } else if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    XCTFail("Login failed")
                }
            }

            semaphore.signal()
        }).resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(FrontToken.getToken() == nil)
    }
//
    // Calling SuperTokens.initialise more than once works!
    func testMoreThanOneCallToInitWorks () {
        TestUtils.startST(validity: 5)
        do {
            // First call
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
            // Second Call
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            XCTFail("Calling init more than once fails the test")
        }
        // Making Post Request to login and then calling init again
        var requestSemaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        }).resume()
        do {
            // Recalling init
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)

        } catch {
            XCTFail("Calling init more than once fails the test")
        }
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        requestSemaphore = DispatchSemaphore(value: 0)
        let userInfoURL = URL(string: "\(testAPIBase)/")
        let userInfoRequest = URLRequest(url: userInfoURL!)
        URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
            userInfoData, userInfoResponse, userInfoError in

            if userInfoError != nil {
                XCTFail("Calling init more than once fails the test")
                requestSemaphore.signal()
                return
            }

            if userInfoResponse as? HTTPURLResponse != nil {
                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                if userInfoHttpResponse.statusCode != 200 {
                    XCTFail("Calling init more than once fails the test")
                }
                requestSemaphore.signal()
            } else {
                XCTFail("Calling init more than once fails the test")
                requestSemaphore.signal()
            }
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }

    func testIfRefreshIsCalledAfterAccessTokenExpires() {
        TestUtils.startST(validity: 3)

        var failed = false
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            failed = true
        }

        let requestSemaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in

            if error != nil {
                failed = true
                requestSemaphore.signal()
                return
            }

            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failed = true
                    requestSemaphore.signal()
                } else {
                    let userInfoURL = URL(string: "\(testAPIBase)/")
                    let userInfoRequest = URLRequest(url: userInfoURL!)

                    sleep(5)

                    URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in

                        if userInfoError != nil {
                            failed = true
                            requestSemaphore.signal()
                            return
                        }

                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failed = true
                            }
                            requestSemaphore.signal()
                        } else {
                            failed = true
                            requestSemaphore.signal()
                        }
                    }).resume()
                }
            } else {
                failed = true
                requestSemaphore.signal()
            }
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        let counter = TestUtils.getRefreshTokenCounter()
        if (counter != 1) {
            failed = true;
        }

        XCTAssertTrue(!failed)
    }

    // 100 requests should yield just 1 refresh call
    func testThatRefreshIsCalledOnlyOnceForMultipleThreads() {
        var failed = true
        TestUtils.startST(validity: 10)

        let runnableCount = 100
        
        let requestSemaphore = DispatchSemaphore(value: 0)
        let countSemaphore = DispatchSemaphore(value: 0)
        var results: [Bool] = []

        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
            URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
                data, response, error in

                if error != nil {
                    requestSemaphore.signal()
                    return
                }

                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                    } else {
                        let userInfoURL = URL(string: "\(testAPIBase)/")
                        let userInfoRequest = URLRequest(url: userInfoURL!)
                        var runnables: [() -> ()] = []
                        let resultsLock = NSObject()

                        for i in 1...runnableCount {
                            runnables.append {
                                URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
                                    userInfoData, userInfoResponse, userInfoError in

                                    defer {
                                        if results.count == runnableCount {
                                            requestSemaphore.signal()
                                        }
                                    }

                                    if userInfoResponse as? HTTPURLResponse != nil {
                                        let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                                        var success = false
                                        if userInfoHttpResponse.statusCode == 200 {
                                            success = true
                                        }
                                        objc_sync_enter(resultsLock)
                                        results.append(success)
                                        objc_sync_exit(resultsLock)
                                    } else {
                                        objc_sync_enter(resultsLock)
                                        results.append(false)
                                        objc_sync_exit(resultsLock)
                                    }
                                }).resume()
                            }
                        }

                        sleep(12)

                        runnables.forEach({
                            runnable in
                            runnable()
                        })
                    }
                } else {
                    requestSemaphore.signal()
                }
            }).resume()
        } catch {

        }

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        let counter = TestUtils.getRefreshTokenCounter()
        XCTAssertTrue(counter == 1)
        XCTAssertTrue(!results.contains(false))
        XCTAssertTrue(results.count == runnableCount)
    }

    // session should not exist on frontend once logout is called
    func testThatSessionDoesNotExistAfterCallingLogout() {
        var failureMessage: String? = nil;
        TestUtils.startST(validity: 10)

        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            failureMessage = "init failed"
        }

        var requestSemaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in

            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }

            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if !SuperTokens.doesSessionExist() {
                        failureMessage = "Session may not exist accoring to library.. but it does!"
                    } else {
                        let frontToken = FrontToken.getToken()
                        let localSessionState = Utils.getLocalSessionState()
                        let antiCSRF = AntiCSRF.getToken(associatedAccessTokenUpdate: localSessionState.lastAccessTokenUpdate);
                        if frontToken == nil || antiCSRF == nil {
                            failureMessage = "antiCSRF or id refresh token is nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        var url = URL(string: "\(testAPIBase)/logout")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in

            if error != nil {
                failureMessage = "logout API error"
                requestSemaphore.signal()
                return
            }

            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                } else {
                    if SuperTokens.doesSessionExist() {
                        failureMessage = "Session exists accoring to library.. but it should not!"
                    } else {
                        let frontToken = FrontToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if frontToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)


        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
//
    // testing doesSessionExist works fine when user is logged in
    func testdoesSessionExsistWhenUserIsLoggedIn () {
        TestUtils.startST(validity: 1)
        var sessionExist:Bool = false
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            XCTFail("unable to initialize")
        }
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
                data, response, error in
                    if error != nil {
                        XCTFail("login Api Error")
                        requestSemaphore.signal()
                        return
                    }
                    if response as? HTTPURLResponse != nil {
                        let httpResponse = response as! HTTPURLResponse
                        if httpResponse.statusCode != 200 {
                            XCTFail("login Api Error")
                            requestSemaphore.signal()
                            return
                        }
                        sessionExist = SuperTokens.doesSessionExist()
                    }
                    requestSemaphore.signal()
            }).resume()
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
              XCTAssertTrue(sessionExist)
        }
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: "\(testAPIBase)/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            URLSession.shared.dataTask(with: request, completionHandler: {
                data, response, error in
                if error != nil {
                    XCTFail("logout Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("logout Api Error")
                        requestSemaphore.signal()
                        return
                    }
                    sessionExist = SuperTokens.doesSessionExist()
                }
                requestSemaphore.signal()
            }).resume()
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            XCTAssertTrue(!sessionExist)
        }
    }
//
    // if not logged in, test that API that requires auth throws session expired.
    func testIfNotLoggedAuthApiThrowSessionExpired () {
        TestUtils.startST(validity: 1)
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
                XCTFail("unable to initialize")
        }
        let requestSemaphore = DispatchSemaphore(value: 0)
        let url = URL(string: "\(testAPIBase)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 401 {
                        requestSemaphore.signal()
                        XCTFail("Session Expired code 401 not returned")
                        return
                    }

                }
                requestSemaphore.signal()
        }).resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }

    // tests other domain's (www.google.com) APIs that don't require authentication work, before, during and after logout.
    func testOtherDomainsWorksWithoutAuthentication () {
        TestUtils.startST(validity: 1)
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            XCTFail("unable to initialize")
        }
        // Before
        // Making Get Request
        let requestSemaphore = DispatchSemaphore(value: 0)
        let fakeGetUrl = URL(string: fakeGetApi)!
        var fakeGetRequest = URLRequest(url: fakeGetUrl)
        fakeGetRequest.httpMethod = "GET"
        URLSession.shared.dataTask(with: fakeGetRequest, completionHandler: {
            getData, getResponse, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if getResponse as? HTTPURLResponse != nil {
                    let httpResponse = getResponse as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("Unable to make Get API Request to external URL")
                        requestSemaphore.signal()
                        return
                    }
                } else {
                    XCTFail("Unable to make Get API Request to external URL")
                    requestSemaphore.signal()
                    return
                }
            requestSemaphore.signal()
        }).resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        // After login
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("login Api Error")
                        requestSemaphore.signal()
                        return
                    }
                    // Get request
                    URLSession.shared.dataTask(with: fakeGetRequest, completionHandler: {
                        getData, getResponse, error in
                            if error != nil {
                                XCTFail("login Api Error")
                                requestSemaphore.signal()
                                return
                            }
                            if getResponse as? HTTPURLResponse != nil {
                                let httpResponse = getResponse as! HTTPURLResponse
                                if httpResponse.statusCode != 200 {
                                    XCTFail("Unable to make Get API Request to external URL")
                                    requestSemaphore.signal()
                                    return
                                }
                            } else {
                                XCTFail("Unable to make Get API Request to external URL")
                                requestSemaphore.signal()
                                return
                            }
                    }).resume()
                }
            requestSemaphore.signal()
        }).resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        // After logout
        let logoutUrl = URL(string: "\(testAPIBase)/logout")
        var request = URLRequest(url: logoutUrl!)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
            if error != nil {
                XCTFail("Logout Api failed")
                requestSemaphore.signal()
                return
            }

            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    // Signbart error when changing the status code here
                     XCTFail("Unable to make Get API Request to external URL")
                     requestSemaphore.signal()
                     return
                 }
                URLSession.shared.dataTask(with: fakeGetRequest, completionHandler: {
                     getData, getResponse, error in
                         if error != nil {
                             XCTFail("login Api Error")
                             requestSemaphore.signal()
                             return
                         }
                         if getResponse as? HTTPURLResponse != nil {
                             let httpResponse = getResponse as! HTTPURLResponse
                             if httpResponse.statusCode != 200 {
                                requestSemaphore.signal()
                                 XCTFail("Unable to make Get API Request to external URL")
                                 return
                             }
                         } else {
                            XCTFail("Unable to make Get API Request to external URL")
                            requestSemaphore.signal()
                            return
                         }
                    requestSemaphore.signal()
                }).resume()
            }
        }).resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    func testThatOldSessionsStillWorkAfterRefreshing() {
        TestUtils.startST()
        do {
            try SuperTokens.initialize(
                apiDomain: testAPIBase,
                tokenTransferMethod: .cookie
            )
        } catch {
            XCTFail("unable to initialize")
        }
        
        var requestSemaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        }).resume()
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let idRefreshCookie = HTTPCookie(properties: [
            .name: "sIdRefreshToken",
            .value: "asdf",
            .domain: "\(testAPIBaseDomain)",
            .path: "/",
        ])
        
        let userInfoURL = URL(string: "\(testAPIBase)/")
        let userInfoRequest = URLRequest(url: userInfoURL!)

        let datatask = URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
            userInfoData, userInfoResponse, userInfoError in

            if userInfoError != nil {
                XCTFail("API failed when unexpected error")
                requestSemaphore.signal()
                return
            }

            if userInfoResponse as? HTTPURLResponse != nil {
                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                requestSemaphore.signal()
            } else {
                XCTFail("API returned invalid response")
                requestSemaphore.signal()
            }
        })
        
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        HTTPCookieStorage.shared.setCookie(idRefreshCookie!)
        
        requestSemaphore = DispatchSemaphore(value: 0)
        var idRefreshInCookies: HTTPCookie? = nil
        
        HTTPCookieStorage.shared.getCookiesFor(datatask, completionHandler: { cookie in
            idRefreshInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sIdRefreshToken"
            })
            
            requestSemaphore.signal()
        })

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if idRefreshInCookies == nil {
            XCTFail("sIdRefreshToken not set to cookies correctly")
        }
        
        requestSemaphore = DispatchSemaphore(value: 0)
        datatask.resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let counter = TestUtils.getRefreshTokenCounter()
        if (counter != 1) {
            XCTFail("Refresh attempted count does not match")
        }
        
        requestSemaphore = DispatchSemaphore(value: 0)
        HTTPCookieStorage.shared.getCookiesFor(datatask, completionHandler: { cookie in
            idRefreshInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sIdRefreshToken"
            })
            
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if idRefreshInCookies != nil {
            XCTFail("sIdRefreshToken still exists when it shouldnt")
        }
    }
    
    func testThatRefreshingOldSessionsWorksFineWithExpiredAccessToken() {
        TestUtils.startST(validity: 1)
        do {
            try SuperTokens.initialize(
                apiDomain: testAPIBase,
                tokenTransferMethod: .cookie
            )
        } catch {
            XCTFail("unable to initialize")
        }
        
        var requestSemaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        }).resume()
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let idRefreshCookie = HTTPCookie(properties: [
            .name: "sIdRefreshToken",
            .value: "asdf",
            .domain: "\(testAPIBaseDomain)",
            .path: "/",
        ])
        
        let accessTokenCookie = HTTPCookie(properties: [
            .name: "sAccessToken",
            .value: "",
            .domain: "\(testAPIBaseDomain)",
            .path: "/",
            .expires: "0"
        ])
        
        let userInfoURL = URL(string: "\(testAPIBase)/")
        let userInfoRequest = URLRequest(url: userInfoURL!)

        let datatask = URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
            userInfoData, userInfoResponse, userInfoError in

            if userInfoError != nil {
                XCTFail("API failed when unexpected error")
                requestSemaphore.signal()
                return
            }

            if userInfoResponse as? HTTPURLResponse != nil {
                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                requestSemaphore.signal()
            } else {
                XCTFail("API returned invalid response")
                requestSemaphore.signal()
            }
        })
        
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        HTTPCookieStorage.shared.setCookie(idRefreshCookie!)
        HTTPCookieStorage.shared.setCookie(accessTokenCookie!)
        
        requestSemaphore = DispatchSemaphore(value: 0)
        var idRefreshInCookies: HTTPCookie? = nil
        var accessTokenInCookies: HTTPCookie? = nil
        
        HTTPCookieStorage.shared.getCookiesFor(datatask, completionHandler: { cookie in
            idRefreshInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sIdRefreshToken"
            })
            
            accessTokenInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sAccessToken"
            })
            
            requestSemaphore.signal()
        })

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if idRefreshInCookies == nil || accessTokenInCookies == nil {
            XCTFail("sIdRefreshToken or sAccessToken not set to cookies correctly")
        }
        
        requestSemaphore = DispatchSemaphore(value: 0)
        datatask.resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        HTTPCookieStorage.shared.getCookiesFor(datatask, completionHandler: { cookie in
            idRefreshInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sIdRefreshToken"
            })
            
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if idRefreshInCookies != nil {
            XCTFail("sIdRefreshToken still exists when it shouldnt")
        }
    }
    
    func testThatOldSessionsStillWorkAfterMovingToHeaders() {
        TestUtils.startST(validity: 1)
        do {
            try SuperTokens.initialize(
                apiDomain: testAPIBase,
                tokenTransferMethod: .cookie
            )
        } catch {
            XCTFail("unable to initialize")
        }
        
        var requestSemaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        }).resume()
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        var accessToken = SuperTokens.getAccessToken()
        
        if accessToken != nil {
            XCTFail("Access token is not nil when it should be")
        }
        
        let idRefreshCookie = HTTPCookie(properties: [
            .name: "sIdRefreshToken",
            .value: "asdf",
            .domain: "\(testAPIBaseDomain)",
            .path: "/",
        ])
        
        let userInfoURL = URL(string: "\(testAPIBase)/")
        let userInfoRequest = URLRequest(url: userInfoURL!)

        let datatask = URLSession.shared.dataTask(with: userInfoRequest, completionHandler: {
            userInfoData, userInfoResponse, userInfoError in

            if userInfoError != nil {
                XCTFail("API failed when unexpected error")
                requestSemaphore.signal()
                return
            }

            if userInfoResponse as? HTTPURLResponse != nil {
                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                requestSemaphore.signal()
            } else {
                XCTFail("API returned invalid response")
                requestSemaphore.signal()
            }
        })
        
        HTTPCookieStorage.shared.cookieAcceptPolicy = .always
        HTTPCookieStorage.shared.setCookie(idRefreshCookie!)
        
        SuperTokens.config?.tokenTransferMethod = .header
        
        requestSemaphore = DispatchSemaphore(value: 0)
        datatask.resume()
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        var idRefreshInCookies: HTTPCookie? = nil
        HTTPCookieStorage.shared.getCookiesFor(datatask, completionHandler: { cookie in
            idRefreshInCookies = cookie?.first(where: { _cookie in
                _cookie.name == "sIdRefreshToken"
            })
            
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if idRefreshInCookies != nil {
            XCTFail("sIdRefreshToken still exists when it shouldnt")
        }
        
        requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokens.signOut(completionHandler: {
            error in
            
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        requestSemaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                }
                requestSemaphore.signal()
        }).resume()
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        accessToken = SuperTokens.getAccessToken()
        
        if accessToken == nil {
            XCTFail("Access token is nil when it shouldnt be")
        }
    }
//
    // session should not exist on frontend once session has actually expired completely
//    func testThatSessionDoesNotExistAfterExpiry() {
//        var failureMessage: String? = nil;
//        TestUtils.startST(validity: 3)
//
//        do {
//            try SuperTokens.initialize(apiDomain: testAPIBase)
//        } catch {
//            failureMessage = "init failed"
//        }
//
//        let requestSemaphore = DispatchSemaphore(value: 0)
//
//        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: {
//            data, response, error in
//
//            if error != nil {
//                failureMessage = "login API error"
//                requestSemaphore.signal()
//                return
//            }
//
//            if response as? HTTPURLResponse != nil {
//                let httpResponse = response as! HTTPURLResponse
//                if httpResponse.statusCode != 200 {
//                    failureMessage = "http response code is not 200";
//                } else {
//                    if !SuperTokens.doesSessionExist() {
//                        failureMessage = "Session may not exist accoring to library.. but it does!"
//                    } else {
//                        let idRefreshToken = IdRefreshToken.getToken()
//                        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: idRefreshToken);
//                        if idRefreshToken == nil || antiCSRF == nil {
//                            failureMessage = "antiCSRF or id refresh token is nil"
//                        }
//                    }
//                }
//            } else {
//                failureMessage = "http response is nil";
//            }
//            sleep(6)
//            requestSemaphore.signal()
//        }).resume()
//
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        if SuperTokens.doesSessionExist() {
//            failureMessage = "session exists, but it should not"
//        } else {
//            let idRefreshToken = IdRefreshToken.getToken()
//            let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-ios-anticsrf-key")
//            if idRefreshToken != nil || antiCSRFToken == nil {
//                failureMessage = "antiCSRF is null or id refresh token is nil"
//            }
//        }
//
//        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
//    }

    func testBreakOutOfSessionRefreshLoopAfterDefaultMaxRetryAttempts() {
        TestUtils.startST()

        var failureMessage: String? = nil;
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, tokenTransferMethod: .cookie)
        } catch {
            failureMessage = "supertokens init failed"
        }

        let requestSemaphore = DispatchSemaphore(value: 0)

        // Step 1: Login request
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: { data, response, error in
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    failureMessage = "Login response code is not 200";
                    requestSemaphore.signal()
                } else {
                    let throw401URL = URL(string: "\(testAPIBase)/throw-401")!
                    var throw401Request = URLRequest(url: throw401URL)
                    throw401Request.httpMethod = "GET"

                    URLSession.shared.dataTask(with: throw401Request, completionHandler: { data, response, error in
                        if let error = error {
                            
                            if (error as NSError).code != 4 {
                                failureMessage = "Expected the error code to be 4 (maxRetryAttemptsReachedForSessionRefresh)"
                                requestSemaphore.signal()
                                return;
                            }
                        
                           
                           let count = TestUtils.getRefreshTokenCounter()
                           if count != 10 {
                               failureMessage = "Expected refresh to be called 10 times but it was called " + String(count) + " times"
                           }
                           requestSemaphore.signal()
                       } else {
                           failureMessage = "Expected /throw-401 request to throw error"
                           requestSemaphore.signal()
                       }
                    }).resume()
                }
            } else {
                failureMessage = "Login response is nil"
                requestSemaphore.signal()
            }
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    

        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    func testBreakOutOfSessionRefreshLoopAfterConfiguredMaxRetryAttempts() {
        TestUtils.startST()

        var failureMessage: String? = nil;
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, maxRetryAttemptsForSessionRefresh: 5, tokenTransferMethod: .cookie)
        } catch {
            failureMessage = "supertokens init failed"
        }

        let requestSemaphore = DispatchSemaphore(value: 0)

        // Step 1: Login request
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: { data, response, error in
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    failureMessage = "Login response code is not 200";
                    requestSemaphore.signal()
                } else {
                    let throw401URL = URL(string: "\(testAPIBase)/throw-401")!
                    var throw401Request = URLRequest(url: throw401URL)
                    throw401Request.httpMethod = "GET"

                    URLSession.shared.dataTask(with: throw401Request, completionHandler: { data, response, error in
                        if let error = error {
                            
                            if (error as NSError).code != 4 {
                                failureMessage = "Expected the error code to be 4 (maxRetryAttemptsReachedForSessionRefresh)"
                                requestSemaphore.signal()
                                return;
                            }
                        
                           
                           let count = TestUtils.getRefreshTokenCounter()
                           if count != 5 {
                               failureMessage = "Expected refresh to be called 5 times but it was called " + String(count) + " times"
                           }
                           requestSemaphore.signal()
                       } else {
                           failureMessage = "Expected /throw-401 request to throw error"
                           requestSemaphore.signal()
                       }
                    }).resume()
                }
            } else {
                failureMessage = "Login response is nil"
                requestSemaphore.signal()
            }
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    

        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }

    func testShouldNotDoSessionRefreshIfMaxRetryAttemptsForSessionRefreshIsZero() {
        TestUtils.startST()

        var failureMessage: String? = nil;
        do {
            try SuperTokens.initialize(apiDomain: testAPIBase, maxRetryAttemptsForSessionRefresh: 0, tokenTransferMethod: .cookie)
        } catch {
            failureMessage = "supertokens init failed"
        }

        let requestSemaphore = DispatchSemaphore(value: 0)

        // Step 1: Login request
        URLSession.shared.dataTask(with: TestUtils.getLoginRequest(), completionHandler: { data, response, error in
            if error != nil {
                failureMessage = "login API error"
                requestSemaphore.signal()
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    failureMessage = "Login response code is not 200";
                    requestSemaphore.signal()
                } else {
                    let throw401URL = URL(string: "\(testAPIBase)/throw-401")!
                    var throw401Request = URLRequest(url: throw401URL)
                    throw401Request.httpMethod = "GET"

                    URLSession.shared.dataTask(with: throw401Request, completionHandler: { data, response, error in
                        if let error = error {
                            
                            if (error as NSError).code != 4 {
                                failureMessage = "Expected the error code to be 4 (maxRetryAttemptsReachedForSessionRefresh)"
                                requestSemaphore.signal()
                                return;
                            }
                        
                           
                           let count = TestUtils.getRefreshTokenCounter()
                           if count != 0 {
                               failureMessage = "Expected refresh to be called 0 times but it was called " + String(count) + " times"
                           }
                           requestSemaphore.signal()
                       } else {
                           failureMessage = "Expected /throw-401 request to throw error"
                           requestSemaphore.signal()
                       }
                    }).resume()
                }
            } else {
                failureMessage = "Login response is nil"
                requestSemaphore.signal()
            }
        }).resume()

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    

        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }

}
