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


class deviceInfoTests: XCTestCase {
    
    enum TestError: Error {
        case runtimeError(String)
    }
    
    static let testAPIBase = "http://127.0.0.1:8080/"
    let refreshTokenAPIURL = "\(testAPIBase)refresh"
    let loginAPIURL = "\(testAPIBase)login"
    let userInfoAPIURL = "\(testAPIBase)userInfo"
    let loggedoutAPIURL = "\(testAPIBase)loggedout"
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
    
    func testDeviceInfoIsSentToVerifyAPI() {
        startST(validity: 10)
        
        var failureMessage: String? = nil;
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
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in
                        
                        if userInfoError != nil {
                            failureMessage = "userInfoError exists";
                            requestSemaphore.signal()
                            return
                        }
                        
                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failureMessage = "reply is not 200";
                            }
                            do {
                                let json = try JSONSerialization.jsonObject(with: userInfoData!) as! Dictionary<String, AnyObject>
                                let sdkVersion = json["sdkVersion"];
                                let sdkName = json["sdkName"];
                                if ((sdkName as! String) != "ios" || (sdkVersion as! String) != SuperTokensConstants.sdkVersion) {
                                    failureMessage = "sdkName or sdkVersion not being sent in verify API";
                                }
                            } catch {
                                failureMessage = "failure while reading json reply"
                            }
                        } else {
                            failureMessage = "reply is nil";
                        }
                        requestSemaphore.signal()
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
    
    func testDeviceInfoIsNotSentToOtherAPIs() {
        
        var failureMessage: String? = nil;
        do {
            try SuperTokens.initialise(refreshTokenEndpoint: refreshTokenAPIURL, sessionExpiryStatusCode: sessionExpiryCode)
        } catch {
            failureMessage = "init failed"
        }
        
        let url = URL(string: loggedoutAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "GET"
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        SuperTokensURLSession.dataTask(request: request, completionHandler: {
            data, response, error in
            
            if response as? HTTPURLResponse != nil {
                let userInfoHttpResponse = response as! HTTPURLResponse
                if userInfoHttpResponse.statusCode != 200 {
                    failureMessage = "reply is not 200";
                }
                do {
                    let json = try JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                    let sdkVersion = json["sdkVersion"];
                    let sdkName = json["sdkName"];
                    if (sdkName != nil || sdkVersion != nil) {
                        failureMessage = "sdkName or sdkVersion being sent in non verify API";
                    }
                } catch {
                    failureMessage = "failure while reading json reply"
                }
            } else {
                failureMessage = "reply is nil";
            }
            requestSemaphore.signal()
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
    func testDeviceInfoIsSentToRefresh() {
        startST(validity: 3)
        
        var failureMessage: String? = nil;
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
                    let userInfoURL = URL(string: self.userInfoAPIURL)
                    let userInfoRequest = URLRequest(url: userInfoURL!)
                    
                    sleep(5)
                    
                    SuperTokensURLSession.dataTask(request: userInfoRequest, completionHandler: {
                        userInfoData, userInfoResponse, userInfoError in
                        
                        if userInfoError != nil {
                            failureMessage = "userInfoError exists";
                            requestSemaphore.signal()
                            return
                        }
                        
                        if userInfoResponse as? HTTPURLResponse != nil {
                            let userInfoHttpResponse = userInfoResponse as! HTTPURLResponse
                            if userInfoHttpResponse.statusCode != 200 {
                                failureMessage = "reply is not 200";
                            }
                        } else {
                            failureMessage = "reply is nil";
                        }
                        requestSemaphore.signal()
                    })
                }
            } else {
                failureMessage = "http response is nil";
                requestSemaphore.signal()
            }
        })
        
        _ = requestSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let json = getRefreshAPIDeviceInfo()
        let sdkVersion = json!["sdkVersion"];
        let sdkName = json!["sdkName"];
        if ((sdkName as! String) != "ios" || (sdkVersion as! String) != SuperTokensConstants.sdkVersion) {
            failureMessage = "sdkName or sdkVersion not being sent in verify API";
        }
        
        XCTAssertTrue(failureMessage == nil, failureMessage ?? "")
    }
    
}
