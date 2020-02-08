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
import Foundation
import XCTest

@testable import session

/* TODO:
 - Proper change in anti-csrf token once access token resets
 - Custom refresh API headers are going through*****
 - Things should work if anti-csrf is disabled.****
 - Test that if you are logged out and you call the /userInfo API, you get session expired output and that refresh token API doesnt get called***
 */

// TODO: please make sure you take of all the print statements.. if any!
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
    let fakeGetApi = "https://jsonplaceholder.typicode.com/todos/1"
    let fakePostApi = "https://jsonplaceholder.typicode.com/posts"
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
    
    // tests APIs that don't require authentication work, before, during and after logout - using our library.
    // TODO: redo test.
    func testNonAuthAPIWorksBeforeDuringAndAfterSession() {
        var failureMessage: String? = nil;
        startST(validity: 10)
        
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        var counter = getRefreshTokenCounter()  // TODO: Do not call this as the API that doesnt requie auth.. make another API like /test and call that using SuperTokensURLSession.newTask
        
        if counter != 0 {
            failureMessage = "API call before failed"
        }
        
        var url = URL(string: loginAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        var requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
                    
                    SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
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
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        startST(validity: 1)    // TODO: set this to something higher for this API
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
        let requestSemaphore = DispatchSemaphore(value: 0)
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        
        // TODO: do mroe stuff here.. calling the "/userInfo" API and making sure you get a proper response etc..
        XCTAssertTrue(true)
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
                    
                    SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
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
            SuperTokensURLSession.newTask(request: request, completionHandler: {
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
                                SuperTokensURLSession.newTask(request: userInfoRequest, completionHandler: {
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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

    // User passed config should be sent as well
    // TODO: by config I do not mean post body. I mean a config like request timeout or anything else that someone may use to "configure" the request. Please redo test
    func testIfUserPassedConfigIsSent () {
         startST(validity: 1)
         do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
          } catch {
                XCTFail("Unable to initialize")
          }
         let requestSemaphore = DispatchSemaphore(value: 0)
        let url = URL(string: checkUserConfig)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let parameters = ["testConfigKey": "testing"]
        do {
             request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch {
            XCTFail("Unable to localize")
        }
        SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    requestSemaphore.signal()
                    XCTFail("login Api Error")
                    return
                }
                if response as? HTTPURLResponse != nil {
                    let httpResponse = response as! HTTPURLResponse
                    if httpResponse.statusCode != 200 {
                        requestSemaphore.signal()
                        XCTFail("login Api Error")
                        return
                    }
                    guard let data = data else {
                        requestSemaphore.signal()
                        XCTFail("No data")
                        return
                    }
                    let responseData = String(data: data, encoding: String.Encoding.utf8)
                    if responseData != "testing" {
                        requestSemaphore.signal()
                         XCTFail("Incorrect Data in Body")
                        return
                    }
                }
            requestSemaphore.signal()
        })
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(true)
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
        let requestSemaphore = DispatchSemaphore(value: 0)
        let url = URL(string: loginAPIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        
        // TODO: test also that after logout, session should not exist
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
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
        XCTAssertTrue(true)
    }
    
    // if any API throws error, it gets propogated to the user properly
    func testApiErrorPropogatesToUsers () {
        startST(validity: 1)
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            XCTFail("unable to initialize")
        }
        let requestSemaphore = DispatchSemaphore(value: 0)
       let url = URL(string: testError)!
       var request = URLRequest(url: url)
       request.httpMethod = "GET"
       SuperTokensURLSession.newTask(request: request, completionHandler: {
            data, response, error in
                if error != nil {
                    XCTFail("login Api Error")  // TODO: you haven't logged in!! please check after copy/paste.
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
        
        // TODO: do the above after login as well.
        XCTAssertTrue(true)
    }
    
    // tests other domain's (www.google.com) APIs that don't require authentication work, before, during and after logout.
    // TODO: redo this test
//    func testOtherDomainsWorksWithoutAuthentication () {
//        startST(validity: 1)
//        do {
//            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
//        } catch {
//            XCTFail("unable to initialize")
//        }
//        // Before
//        // Making Get Request
//        let requestSemaphore = DispatchSemaphore(value: 0)
//        let fakeGetUrl = URL(string: fakeGetApi)!
//        var fakeGetRequest = URLRequest(url: fakeGetUrl)
//        fakeGetRequest.httpMethod = "GET"
//        SuperTokensURLSession.newTask(request: fakeGetRequest, completionHandler: {
//            getData, getResponse, error in
//                if error != nil {
//                    XCTFail("login Api Error")
//                    requestSemaphore.signal()
//                    return
//                }
//                if getResponse as? HTTPURLResponse != nil {
//                    let httpResponse = getResponse as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        XCTFail("Unable to make Get API Request to external URL")
//                        requestSemaphore.signal()
//                        return
//                    }
//                } else {
//                    XCTFail("Unable to make Get API Request to external URL")
//                    requestSemaphore.signal()
//                    return
//                }
//            requestSemaphore.signal()
//         })
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        // Making Post Request
//        let fakePostUrl = URL(string: fakePostApi)!
//        var fakePostRequest = URLRequest(url: fakePostUrl)
//        fakePostRequest.httpMethod = "POST"
//        fakePostRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        let parameters = ["testConfigKey": "testing"]
//        do {
//             fakePostRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
//        } catch {
//            XCTFail("Unable to localize")
//        }
//        SuperTokensURLSession.newTask(request: fakePostRequest, completionHandler: {
//            postData, postResponse, error in
//                if error != nil {
//                    XCTFail("Api Error")
//                    requestSemaphore.signal()
//                    return
//                }
//                if postResponse as? HTTPURLResponse != nil {
//                    let httpResponse = postResponse as! HTTPURLResponse
//                    if httpResponse.statusCode != 201 {
//                        XCTFail("Incorrect Status code")
//                        requestSemaphore.signal()
//                        return
//                    }
//                } else {
//                    requestSemaphore.signal()
//                    XCTFail("Problem with response of post request")
//                    return
//                }
//            requestSemaphore.signal()
//        })
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//
//        // After login
//        let url = URL(string: loginAPIURL)!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        SuperTokensURLSession.newTask(request: request, completionHandler: {
//            data, response, error in
//                if error != nil {
//                    XCTFail("login Api Error")
//                    requestSemaphore.signal()
//                    return
//                }
//                if response as? HTTPURLResponse != nil {
//                    let httpResponse = response as! HTTPURLResponse
//                    if httpResponse.statusCode != 200 {
//                        XCTFail("login Api Error")
//                        requestSemaphore.signal()
//                        return
//                    }
//                    // Get request
//                    SuperTokensURLSession.newTask(request: fakeGetRequest, completionHandler: {
//                        getData, getResponse, error in
//                            if error != nil {
//                                XCTFail("login Api Error")
//                                requestSemaphore.signal()
//                                return
//                            }
//                            if getResponse as? HTTPURLResponse != nil {
//                                let httpResponse = getResponse as! HTTPURLResponse
//                                if httpResponse.statusCode != 200 {
//                                    XCTFail("Unable to make Get API Request to external URL")
//                                    requestSemaphore.signal()
//                                    return
//                                }
//                            } else {
//                                XCTFail("Unable to make Get API Request to external URL")
//                                requestSemaphore.signal()
//                                return
//                            }
//                    })
//                    // Making Post Request
//                    // Error: Below Fake Post not being called
//                    SuperTokensURLSession.newTask(request: fakePostRequest, completionHandler: {
//                        postData, postResponse, error in
//                            if error != nil {
//                                XCTFail("Api Error")
//                                requestSemaphore.signal()
//                                return
//                            }
//                            if postResponse as? HTTPURLResponse != nil {
//                                let httpResponse = postResponse as! HTTPURLResponse
//                                // This should fail, correct status code is 201
//                                if httpResponse.statusCode != 200 {
//                                    requestSemaphore.signal()
//                                    XCTFail("Incorrect Status code")
//                                    return
//                                }
//                            } else {
//                                requestSemaphore.signal()
//                                XCTFail("Problem with response of post request")
//                                return
//                            }
//                    })
//                }
//            requestSemaphore.signal()
//        })
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        // After logout
//        let logoutUrl = URL(string: logoutAPIURL)
//        request = URLRequest(url: logoutUrl!)
//        request.httpMethod = "POST"
//        SuperTokensURLSession.newTask(request: request, completionHandler: {
//            data, response, error in
//            if error != nil {
//                XCTFail("Logout Api failed")
//                requestSemaphore.signal()
//                return
//            }
//
//            if response as? HTTPURLResponse != nil {
//                let httpResponse = response as! HTTPURLResponse
//                if httpResponse.statusCode != 200 {
//                    // Signbart error when changing the status code here
//                     XCTFail("Unable to make Get API Request to external URL")
//                     requestSemaphore.signal()
//                     return
//                 }
//                SuperTokensURLSession.newTask(request: fakeGetRequest, completionHandler: {
//                     getData, getResponse, error in
//                         if error != nil {
//                             XCTFail("login Api Error")
//                             requestSemaphore.signal()
//                             return
//                         }
//                         if getResponse as? HTTPURLResponse != nil {
//                             let httpResponse = getResponse as! HTTPURLResponse
//                             if httpResponse.statusCode != 200 {
//                                requestSemaphore.signal()
//                                 XCTFail("Unable to make Get API Request to external URL")
//                                 return
//                             }
//                         } else {
//                            XCTFail("Unable to make Get API Request to external URL")
//                            requestSemaphore.signal()
//                            return
//                         }
//                 })
//                // Making Post Request
//                let fakePostUrl = URL(string: self.fakePostApi)!
//                var fakePostRequest = URLRequest(url: fakePostUrl)
//                fakePostRequest.httpMethod = "POST"
//                fakePostRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
//                let parameters = ["testConfigKey": "testing"]
//                do {
//                     fakePostRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
//                } catch {
//                    XCTFail("Unable to localize")
//                }
//                SuperTokensURLSession.newTask(request: fakePostRequest, completionHandler: {
//                    postData, postResponse, error in
//                        if error != nil {
//                            requestSemaphore.signal()
//                            XCTFail("Api Error")
//                            return
//                        }
//                        if postResponse as? HTTPURLResponse != nil {
//                            let httpResponse = postResponse as! HTTPURLResponse
//                            if httpResponse.statusCode != 200 {
//                                requestSemaphore.signal()
//                                XCTFail("Incorrect Status code")
//                                return
//                            }
//                        } else {
//                            requestSemaphore.signal()
//                            XCTFail("Problem with response of post request")
//                            return
//                        }
//                })
//            }
//            requestSemaphore.signal()
//        })
//        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
//        XCTAssertTrue(true)
//    }
    
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
        SuperTokensURLSession.newTask(request: testRequest, completionHandler: {
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
                                XCTFail("Custom Header for Logged in user not equal")   // TODO: please read up on this and then do we need the below two lines of code??
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
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
                        XCTFail("login Api Error")  // TODO: some places you have it above, some places below (the signal call). Please make it consistent.
                        return
                }
                SuperTokensURLSession.newTask(request: testRequest, completionHandler: {
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
    
        // TODO: why is there twice here? Copy/paste is OK, but be aware please.
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        XCTAssertTrue(true) // TODO: remove this from all tests..
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
        
        SuperTokensURLSession.newTask(request: request, completionHandler: {
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
