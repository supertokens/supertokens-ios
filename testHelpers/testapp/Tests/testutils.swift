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

let testAPIBaseDomain = "127.0.0.1"
let testAPIBase = "http://\(testAPIBaseDomain):8080"
let beforeEachAPIURL = "\(testAPIBase)beforeeach"
let refreshDeviceInfoAPIURL = "\(testAPIBase)refreshDeviceInfo"

class TestUtils {
    static func afterAllTests(callback: @escaping () -> Void) {
        let url = URL(string: "\(testAPIBase)/after")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let task = getTestingUrlSession().dataTask(with: request, completionHandler: { data, response, error in
            
            let stopRequest = URLRequest(url: URL(string: "\(testAPIBase)/stopst")!)
            getTestingUrlSession().dataTask(with: stopRequest, completionHandler: {
                _, _, _ in
                
                callback()
            }).resume()
        })
        task.resume()
    }
    
    static func beforeAllTests(callback: @escaping () -> Void) {
        let url = URL(string: "\(testAPIBase)/test/startServer")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        let task = getTestingUrlSession().dataTask(with: request, completionHandler: { data, response, error in
            
            callback()
        })
        task.resume()
    }
    
    static func beforeEachTest(callback: @escaping () -> Void) {
        SuperTokens.resetForTests()
        var beforeeachRequest = URLRequest(url: URL(string: "\(testAPIBase)/beforeeach")!)
        beforeeachRequest.httpMethod = "POST"
        getTestingUrlSession().dataTask(with: beforeeachRequest, completionHandler: {
            _, _, _ in
            
            callback()
        }).resume()
    }
    
    static func getTestingUrlSession() -> URLSession {
        return URLSession(configuration: URLSessionConfiguration.default)
    }
    
    internal static func startST(validity: Int = 1, refreshValidity: Double? = nil, disableAntiCSRF: Bool? = false) {
        let semaphore = DispatchSemaphore(value: 0)
        startSTHelper(validity: validity, disableAntiCSRF: disableAntiCSRF, successCallback: {
            semaphore.signal()
        }) {
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    //
    private static func startSTHelper(validity: Int = 1, disableAntiCSRF: Bool? = false, successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        let url = URL(string: "\(testAPIBase)/startst")
        var request = URLRequest(url: url!)
        
        var json: [String: Any] = ["accessTokenValidity": validity, "enableAntiCsrf": !disableAntiCSRF!]

        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        let task = getTestingUrlSession().dataTask(with: request, completionHandler: { data, response, error in
            defer {
                semaphore.signal()
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode == 200 {
                    successCallback()
                    return;
                }
            }
            failureCallback()
        })
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
    }
    
    internal static func getRefreshTokenCounter() -> Int {
        let refreshCounterSemaphore = DispatchSemaphore(value: 0)
        var result = -1;
        getRefreshTokenCounterHelper(successCallback: {
            counter in
            result = counter
            refreshCounterSemaphore.signal()
        }, failureCallback: {
            refreshCounterSemaphore.signal()
        })
        _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
        return result;
    }
    
    private static func getRefreshTokenCounterHelper(successCallback: @escaping (Int) -> Void, failureCallback: @escaping () -> Void) {
        let refreshCounterSempahore = DispatchSemaphore(value: 0)
        let url = URL(string: "\(testAPIBase)/refreshAttemptedTime")
        let request = URLRequest(url: url!)
        let task = getTestingUrlSession().dataTask(with: request, completionHandler: { data, response, error in
            defer {
                refreshCounterSempahore.signal()
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureCallback()
                    return
                }
                
                if data == nil {
                    failureCallback()
                    return
                }
                
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
                    let counterValue = jsonResponse.value(forKey: "counter") as? Int
                    if counterValue == nil {
                        failureCallback()
                    } else {
                        successCallback(counterValue!)
                    }
                } catch {
                    failureCallback()
                }
            } else {
                failureCallback()
            }
        })
        task.resume()
        _ = refreshCounterSempahore.wait(timeout: .distantFuture)
    }
    
    static func getLoginRequest() -> URLRequest {
        let url = URL(string: "\(testAPIBase)/login")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        
        let json: [String: Any] = ["userId": "supertokens-ios-tests"]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        return request
    }
}


//
//internal func beforeEachAPI(successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
//    let semaphore = DispatchSemaphore(value: 0)
//    let url = URL(string: beforeEachAPIURL)
//    var request = URLRequest(url: url!)
//    request.httpMethod = "POST"
//    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
//        defer {
//            semaphore.signal()
//        }
//        
//        if response as? HTTPURLResponse != nil {
//            let httpResponse = response as! HTTPURLResponse
//            if httpResponse.statusCode == 200 {
//                successCallback()
//                return;
//            }
//        }
//        failureCallback()
//    })
//    task.resume()
//    _ = semaphore.wait(timeout: .distantFuture)
//}
//
//
//internal func getRefreshTokenCounterUsingST() -> Int {
//    let refreshCounterSemaphore = DispatchSemaphore(value: 0)
//    var result = -1;
//    getRefreshTokenCounterHelperUsingST(successCallback: {
//        counter in
//        result = counter
//        refreshCounterSemaphore.signal()
//    }, failureCallback: {
//        refreshCounterSemaphore.signal()
//    })
//    _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
//    return result;
//}
//
//
//private func getRefreshTokenCounterHelperUsingST(successCallback: @escaping (Int) -> Void, failureCallback: @escaping () -> Void) {
//    let refreshCounterSempahore = DispatchSemaphore(value: 0)
//    let url = URL(string: refreshCounterAPIURL)
//    let request = URLRequest(url: url!)
//    SuperTokensURLSession.dataTask(request: request, completionHandler: { data, response, error in
//        defer {
//            refreshCounterSempahore.signal()
//        }
//        
//        if response as? HTTPURLResponse != nil {
//            let httpResponse = response as! HTTPURLResponse
//            if httpResponse.statusCode != 200 {
//                failureCallback()
//                return
//            }
//            
//            if data == nil {
//                failureCallback()
//                return
//            }
//            
//            do {
//                let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
//                let counterValue = jsonResponse.value(forKey: "counter") as? Int
//                if counterValue == nil {
//                    failureCallback()
//                } else {
//                    successCallback(counterValue!)
//                }
//            } catch {
//                failureCallback()
//            }
//        } else {
//            failureCallback()
//        }
//    })
//    _ = refreshCounterSempahore.wait(timeout: .distantFuture)
//}
//
//internal func getRefreshAPIDeviceInfo() -> NSDictionary? {
//    let refreshCounterSemaphore = DispatchSemaphore(value: 0)
//    var result: NSDictionary? = nil;
//    getRefreshAPIDeviceInfoHelper(successCallback: {
//        json in
//        result = json
//        refreshCounterSemaphore.signal()
//    }, failureCallback: {
//        refreshCounterSemaphore.signal()
//    })
//    _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
//    return result;
//}
//
//private func getRefreshAPIDeviceInfoHelper(successCallback: @escaping (NSDictionary) -> Void, failureCallback: @escaping () -> Void) {
//    let refreshCounterSempahore = DispatchSemaphore(value: 0)
//    let url = URL(string: refreshDeviceInfoAPIURL)
//    let request = URLRequest(url: url!)
//    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
//        
//        defer {
//            refreshCounterSempahore.signal()
//        }
//        
//        if response as? HTTPURLResponse != nil {
//            let httpResponse = response as! HTTPURLResponse
//            if httpResponse.statusCode != 200 {
//                failureCallback()
//                return
//            }
//            
//            if data == nil {
//                failureCallback()
//                return
//            }
//            do {
//                let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
//                successCallback(jsonResponse)
//            } catch {
//                failureCallback()
//            }
//        } else {
//            failureCallback()
//        }
//    })
//    task.resume()
//    _ = refreshCounterSempahore.wait(timeout: .distantFuture)
//}
