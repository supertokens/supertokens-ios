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
@testable import SuperTokensSession

/* TODO:
 - Proper change in anti-csrf token once access token resets
 - User passed config should be sent as well
 */

class sessionTests: XCTestCase {
    static let testAPIBase = "http://127.0.0.1:8080/"
    let refreshTokenAPIURL = "\(testAPIBase)refresh"
    let loginAPIURL = "\(testAPIBase)login"
    let userInfoAPIURL = "\(testAPIBase)userInfo"
    let logoutAPIURL = "\(testAPIBase)logout"
    let headerAPIURL = "\(testAPIBase)header"
    let testinApiUrl = "\(testAPIBase)testing"
    let refreshCounterAPIURL = "\(testAPIBase)refreshCounter"
    let checkUserConfig = "\(testAPIBase)checkUserConfig"
    let testError = "\(testAPIBase)testError"
    let fakeGetApi = "https://www.google.com"
    let refreshCustomHeader = "\(testAPIBase)refreshHeaderInfo"
    let sessionExpiryCode = 440
    

    override class func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)
        afterAPI(successCallback: {
            semaphore.signal()
        }, failureCallback: {
            semaphore.signal()
        })
         _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        SuperTokens.isInitCalled = false
        AntiCSRF.removeToken()
        IdRefreshToken.removeToken()
        
        let semaphore = DispatchSemaphore(value: 0)
        beforeEachAPI(successCallback: {
            semaphore.signal()
        }, failureCallback: {
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // Test that if you are logged out and you call the /userInfo API, you get session expired output and that refresh token API doesnt get called
    func testSessionExpiredErrorAndNoRefreshToken() {
        startST(validity: 3)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail()
        }
        
        do {
            let userInfoURL = URL(string: self.userInfoAPIURL)
            let userInfoRequest = URLRequest(url: userInfoURL!)
            let requestSemaphore = DispatchSemaphore(value: 0)
            
            SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
                userInfoData, userInfoResponse, userInfoError in
                
                if userInfoError != nil {
                    XCTFail()
                    requestSemaphore.signal()
                    return
                }
                
                if userInfoResponse as? HTTPURLResponse != nil {
                    let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                    if userInfoHttpResponse.statusCode != 440 {
                        XCTFail()
                    }
                    requestSemaphore.signal()
                } else {
                    XCTFail()
                    requestSemaphore.signal()
                }
            })
            
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
        
        let counter = getRefreshTokenCounter()
        if (counter != 0) {
            XCTFail()
        }
    }
    
    // Things should work if anti-csrf is disabled.
    func testThingsWorkIfAntiCSRFIsDisabled() {
        startST(validity: 3, refreshValidity: 2, disableAntiCSRF: true)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail()
        }
        
        do {
            let url = URL(string: loginAPIURL)
            var request = URLRequest(url: url!)
            request.httpMethod = "POST"
            let requestSemaphore = DispatchSemaphore(value: 0)
            
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
                data, response, error in
                
                if error != nil {
                    XCTFail()
                    requestSemaphore.signal()
                    return
                }
                
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail()
                        requestSemaphore.signal()
                    } else {
                        let userInfoURL = URL(string: self.userInfoAPIURL)
                        let userInfoRequest = URLRequest(url: userInfoURL!)
                        
                        sleep(5)
                        
                        SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
                            userInfoData, userInfoResponse, userInfoError in
                            
                            if userInfoError != nil {
                                XCTFail()
                                requestSemaphore.signal()
                                return
                            }
                            
                            if userInfoResponse as? HTTPURLResponse != nil {
                                let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                                if userInfoHttpResponse.statusCode != 200 {
                                    XCTFail()
                                }
                                requestSemaphore.signal()
                            } else {
                                XCTFail()
                                requestSemaphore.signal()
                            }
                        })
                    }
                } else {
                    XCTFail()
                    requestSemaphore.signal()
                }
            })
            
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
        
        let counter = getRefreshTokenCounter()
        if (counter != 1) {
            XCTFail()
        }
        
        // logout
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: logoutAPIURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            XCTAssertTrue(!SuperTokens.doesSessionExist())
        }
    }
    
    // Custom refresh API headers are going through
    func testCustomHeadersForRefreshAPI() {
        startST(validity: 3)
        
        do {
            let dict:NSDictionary = ["custom-header" : "custom-value"]
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode, refreshAPICustomHeaders: dict)
        } catch {
            XCTFail("Init failed")
        }
        
        do {
            let url = URL(string: loginAPIURL)
            var request = URLRequest(url: url!)
            request.httpMethod = "POST"
            let requestSemaphore = DispatchSemaphore(value: 0)
            
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idBefore = IdRefreshToken.getToken()
                        sleep(5)
                        let userInfoURL = URL(string: self.userInfoAPIURL)
                        let userInfoRequest = URLRequest(url: userInfoURL!)
                        
                        SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
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
                                let idAfter = IdRefreshToken.getToken()
                                if idAfter == idBefore {
                                    XCTFail("id before and after are not the same!")
                                }
                                requestSemaphore.signal()
                            } else {
                                XCTFail("userInfo API response is nil")
                                requestSemaphore.signal()
                            }
                        })
                    }
                } else {
                    XCTFail("http response is nil");
                    requestSemaphore.signal()
                }
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
        
        do  {
            let url = URL(string: refreshCustomHeader)
            var request = URLRequest(url: url!)
            request.httpMethod = "GET"
            let requestSemaphore = DispatchSemaphore(value: 0)
            
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
            })
            
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    // tests APIs that don't require authentication work, before, during and after logout - using our library.
    func testNonAuthAPIWorksBeforeDuringAndAfterSession() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        var counter = getRefreshTokenCounterUsingST()
        
        if counter != 0 {
            failureMessage = "API call before failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
            data, response, error in
            
            defer {
                requestSemaphore.signal()
            }
            
            if error != nil {
                failureMessage = "login API error"
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                }
            } else {
                failureMessage = "http response is nil";
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounterUsingST()
        if counter != 0 {
            failureMessage = "API call during failed"
        }
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounterUsingST()
        if counter != 0 {
            failureMessage = "API call after failed"
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // tests APIs that don't require authentication work, before, during and after logout - not using our lib.
    func testNonAuthAPIWorksBeforeDuringAndAfterSessionWithURLSession() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }

        var counter = getRefreshTokenCounter()
        
        if counter != 0 {
            failureMessage = "API call before failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
            data, response, error in
            
            defer {
                requestSemaphore.signal()
            }
            
            if error != nil {
                failureMessage = "login API error"
                return
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureMessage = "http response code is not 200";
                }
            } else {
                failureMessage = "http response is nil";
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call during failed"
        }
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        counter = getRefreshTokenCounter()
        if counter != 0 {
            failureMessage = "API call after failed"
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // while logged in, test that APIs that there is proper change in id refresh stored in storage
    func testIdRefreshChange() {
        var failureMessage: String? = nil;
        startST(validity: 3)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                    requestSemaphore.signal()
                } else {
                    let idBefore = IdRefreshToken.getToken()
                    sleep(5)
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in
                        
                        if userInfoError != nil {
                            failureMessage = "userInfo API error"
                            requestSemaphore.signal()
                            return
                        }
                        
                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failureMessage = "userInfo API non 200 HTTP status code"
                            }
                            let idAfter = IdRefreshToken.getToken()
                            if idAfter == idBefore {
                                failureMessage = "id before and after are not the same!"
                            }
                            requestSemaphore.signal()
                        } else {
                            failureMessage = "userInfo API response is nil"
                            requestSemaphore.signal()
                        }
                    })
                }
            } else {
                failureMessage = "http response is nil";
                requestSemaphore.signal()
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
        
    }
    
    func testThatRequestsFailIfInitIsNotCalled() {
        var failed = true
        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(string: loginAPIURL)
        let request = URLRequest(url: url!)
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
            data, response, error in
            defer {
                semaphore.signal()
            }
            if error != nil {
                switch error! {
                    case SuperTokensError.illegalAccess("SuperTokens.init must be called before calling SuperTokensURLSession.newTask"):
                        failed = false
                        break
                    default:
                        break
                }
            }
        })
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(!failed)
    }
    
    // Calling SuperTokens.initialise more than once works!
    func testMoreThanOneCallToInitWorks () {
        startST(validity: 5)
        do {
            // First call
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
            // Second Call
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("Calling init more than once fails the test")
        }
        // Making Post Request to login and then calling init again
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
        })
        do {
            // Recalling init
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        
        } catch {
            XCTFail("Calling init more than once fails the test")
        }
         _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        requestSemaphore = DispatchSemaphore(value: 0)
        let userInfoURL = URL(string: self.userInfoAPIURL)
        let userInfoRequest = URLRequest(url: userInfoURL!)
        SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
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
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    func testIfRefreshIsCalledAfterAccessTokenExpires() {
        startST(validity: 3)
        
        var failed = false
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failed = true
        }
        
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    sleep(5)
                    
                    SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
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
                    })
                }
            } else {
                failed = true
                requestSemaphore.signal()
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let counter = getRefreshTokenCounter()
        if (counter != 1) {
            failed = true;
        }
        
        XCTAssertTrue(!failed)
    }
    
    // 300 requests should yield just 1 refresh call
    func testThatRefreshIsCalledOnlyOnceForMultipleThreads() {
        var failed = true
        startST(validity: 10)
        
        let runnableCount = 300

        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        let countSemaphore = DispatchSemaphore(value: 0)
        var results: [Bool] = []

        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let userInfoURL = URL(string: self.userInfoAPIURL)
                        let userInfoRequest = URLRequest(url: userInfoURL!)
                        var runnables: [() -> ()] = []
                        let resultsLock = NSObject()

                        for i in 1...runnableCount {
                            runnables.append {
                                SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
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
                                })
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
            })
        } catch {

        }

        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        let counter = getRefreshTokenCounter()
        if (counter == 1 && !results.contains(false) && results.count == runnableCount) {
            failed = false;
        }

        XCTAssertTrue(!failed)
    }
    
    // session should not exist on frontend once logout is called
    func testThatSessionDoesNotExistAfterCallingLogout() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: idRefreshToken);
                        if idRefreshToken == nil || antiCSRF == nil {
                            failureMessage = "antiCSRF or id refresh token is nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        url = URL(string: logoutAPIURL)
        request = URLRequest(url: url!)
        request.httpMethod = "POST"
        requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
                        if idRefreshToken != nil || antiCSRFToken != nil {
                            failureMessage = "antiCSRF or id refresh token is not nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    // testing doesSessionExist works fine when user is logged in
    func testdoesSessionExsistWhenUserIsLoggedIn () {
        startST(validity: 1)
        var sessionExist:Bool = false
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("unable to initialize")
        }
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: loginAPIURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
              XCTAssertTrue(sessionExist)
        }
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: logoutAPIURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
            XCTAssertTrue(!sessionExist)
        }
    }
    
    // if not logged in, test that API that requires auth throws session expired.
    func testIfNotLoggedAuthApiThrowSessionExpired () {
        startST(validity: 1)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
                XCTFail("unable to initialize")
        }
        let requestSemaphore = DispatchSemaphore(value: 0)
        let url = URL(string: userInfoAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 440 {
                        requestSemaphore.signal()
                        XCTFail("Session Expired code 440 not returned")
                        return
                    }
                    
                }
                requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // if any API throws error, it gets propogated to the user properly
    func testApiErrorPropogatesToUsers () {
        startST(validity: 1)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("unable to initialize")
        }
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: testError)!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
                data, response, error in
                    if error != nil {
                        XCTFail("Api Error")
                        requestSemaphore.signal()
                        return
                    }
                    if response as? HTTPURLResponse != nil {
                        let httpResponse = response as! HTTPURLResponse
                        if httpResponse.statusCode != 500 {
                            requestSemaphore.signal()
                            XCTFail("Unexpected Status code")
                            return
                        }
                        guard let data = data else {
                            requestSemaphore.signal()
                            XCTFail("No data")
                            return
                        }
                        let responseData = String(data: data, encoding: String.Encoding.utf8)
                        if responseData != "Internal Server Error" {
                            XCTFail("Incorrect Error Message")
                            requestSemaphore.signal()
                            return
                        }
                    }
                requestSemaphore.signal()
             })
             _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }

        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: loginAPIURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                }
                requestSemaphore.signal()
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
        
        do {
            let requestSemaphore = DispatchSemaphore(value: 0)
            let url = URL(string: testError)!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            SuperTokensURLSession.dataTask(request: request, completionHandler: {
                data, response, error in
                if error != nil {
                    XCTFail("Api Error")
                    requestSemaphore.signal()
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 500 {
                        requestSemaphore.signal()
                        XCTFail("Unexpected Status code")
                        return
                    }
                    guard let data = data else {
                        requestSemaphore.signal()
                        XCTFail("No data")
                        return
                    }
                    let responseData = String(data: data, encoding: String.Encoding.utf8)
                    if responseData != "Internal Server Error" {
                        XCTFail("Incorrect Error Message")
                        requestSemaphore.signal()
                        return
                    }
                }
                requestSemaphore.signal()
            })
            _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    // tests other domain's (www.google.com) APIs that don't require authentication work, before, during and after logout.
    func testOtherDomainsWorksWithoutAuthentication () {
        startST(validity: 1)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("unable to initialize")
        }
        // Before
        // Making Get Request
        let requestSemaphore = DispatchSemaphore(value: 0)
        let fakeGetUrl = URL(string: fakeGetApi)!
        var fakeGetRequest = URLRequest(url: fakeGetUrl)
        fakeGetRequest.httpMethod = "GET"
        SuperTokensURLSession.dataTask(request: fakeGetRequest, completionHandler: {
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
         })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)

        // After login
        let url = URL(string: loginAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                    SuperTokensURLSession.dataTask(request: fakeGetRequest, completionHandler: {
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
                    })
                }
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        // After logout
        let logoutUrl = URL(string: logoutAPIURL)
        request = URLRequest(url: logoutUrl!)
        request.httpMethod = "POST"
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                SuperTokensURLSession.dataTask(request: fakeGetRequest, completionHandler: {
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
                 })
            }
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // test custom headers are being sent when logged in and when not.
    func testCheckCustomHeadersForUsers () {
        startST(validity: 1)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("unable to initialize")
        }
        let requestSemaphore = DispatchSemaphore(value: 0)
        // Case1: When user is not logged in
       let testURL = URL(string: testinApiUrl)!
       var testRequest = URLRequest(url: testURL)
       testRequest.httpMethod = "POST"
        // Setting custom Headers
        testRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        testRequest.setValue("st-custom-header", forHTTPHeaderField: "testing")
        SuperTokensURLSession.dataTask(request: testRequest, completionHandler: {
            testData, testResponse, testError in
                if testError != nil {
                    XCTFail("Api Error")
                    requestSemaphore.signal()
                    return
                }
                if testResponse as? HTTPURLResponse != nil {
                    let httpResponse = testResponse as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        XCTFail("Api Error")
                        requestSemaphore.signal()
                        return
                    } else {
                        if let customHeaders = httpResponse.allHeaderFields["testing"] as? String  {
                            if (customHeaders != "st-custom-header" ) {
                                XCTFail("Custom Header for Logged in user not equal")
                                requestSemaphore.signal()
                                return
                            }
                        } else {
                            requestSemaphore.signal()
                            XCTFail("Custom Header for not logged in user not equal")
                        }
                    }
                }
                requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    
       //Case2: When user is logged in
    
       //Logging in user
        let url = URL(string: loginAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                SuperTokensURLSession.dataTask(request: testRequest, completionHandler: {
                    testData, testResponse, testError in
                        if testError != nil {
                            XCTFail("login Api Error")
                            requestSemaphore.signal()
                            return
                        }
                        if testResponse as? HTTPURLResponse != nil {
                            let httpResponse = testResponse as! HTTPURLResponse
                            if httpResponse.statusCode != 200 {
                                XCTFail("login Api Error")
                                    requestSemaphore.signal()
                                    return
                                } else {
                                    if let customHeaders = httpResponse.allHeaderFields["testing"] as? String  {
                                        if (customHeaders != "st-custom-header" ) {
                                            XCTFail("Custom Header for Logged in user not equal")
                                            requestSemaphore.signal()
                                            return
                                        }
                                    } else {
                                        requestSemaphore.signal()
                                        XCTFail("Custom Header for logged in user not equal")
                                    }
                                }
                            }
                        requestSemaphore.signal()
                    })
                requestSemaphore.signal()
                }
            })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    // session should not exist on frontend once session has actually expired completely
    func testThatSessionDoesNotExistAfterExpiry() {
        var failureMessage: String? = nil;
        startST(validity: 3, refreshValidity: 4/60)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
         
        let url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
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
                        let idRefreshToken = IdRefreshToken.getToken()
                        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: idRefreshToken);
                        if idRefreshToken == nil || antiCSRF == nil {
                            failureMessage = "antiCSRF or id refresh token is nil"
                        }
                    }
                }
            } else {
                failureMessage = "http response is nil";
            }
            sleep(6)
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if SuperTokens.doesSessionExist() {
            failureMessage = "session exists, but it should not"
        } else {
            let idRefreshToken = IdRefreshToken.getToken()
            let antiCSRFToken = UserDefaults.standard.string(forKey: "supertokens-android-anticsrf-key")
            if idRefreshToken != nil || antiCSRFToken == nil {
                failureMessage = "antiCSRF is null or id refresh token is nil"
            }
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
}
