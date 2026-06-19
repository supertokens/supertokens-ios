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
let testAPIBase = (ProcessInfo.processInfo.environment["TEST_BACKEND_URL"] ?? "http://\(testAPIBaseDomain):8080").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
let beforeEachAPIURL = "\(testAPIBase)beforeeach"
let refreshDeviceInfoAPIURL = "\(testAPIBase)refreshDeviceInfo"

class TestUtils {
    private static let harnessTimeout: TimeInterval = 300

    private static func addHarnessAuthHeader(_ request: inout URLRequest) {
        if let token = ProcessInfo.processInfo.environment["TEST_HARNESS_AUTH_TOKEN"], !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "x-test-harness-token")
        }
    }

    private static func runHarnessRequest(_ request: URLRequest) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?

        getTestingUrlSession().dataTask(with: request, completionHandler: { data, response, error in
            defer {
                semaphore.signal()
            }

            if let error = error {
                resultError = error
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                resultError = NSError(domain: "TestHarness", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "No HTTP response from \(request.url?.absoluteString ?? "<unknown>")"
                ])
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                resultError = NSError(domain: "TestHarness", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Harness request failed: \(httpResponse.statusCode) \(body)"
                ])
                return
            }
        }).resume()

        let timeout = DispatchTime.now() + .milliseconds(Int((harnessTimeout + 5) * 1000))
        if semaphore.wait(timeout: timeout) == .timedOut {
            throw NSError(domain: "TestHarness", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Harness request timed out: \(request.url?.absoluteString ?? "<unknown>")"
            ])
        }

        if let resultError = resultError {
            throw resultError
        }
    }

    static func afterAllTests(callback: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        defer {
            callback()
        }

        var cleanupError: Error?

        var afterRequest = URLRequest(url: URL(string: "\(testAPIBase)/after")!)
        afterRequest.httpMethod = "POST"
        addHarnessAuthHeader(&afterRequest)

        do {
            try runHarnessRequest(afterRequest)
        } catch {
            cleanupError = error
        }

        var stopRequest = URLRequest(url: URL(string: "\(testAPIBase)/stopst")!)
        stopRequest.httpMethod = "POST"
        addHarnessAuthHeader(&stopRequest)

        do {
            try runHarnessRequest(stopRequest)
        } catch {
            cleanupError = cleanupError ?? error
        }

        if let cleanupError = cleanupError {
            XCTFail("Harness cleanup failed: \(cleanupError)", file: file, line: line)
        }
    }
    
    static func beforeAllTests(callback: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        var request = URLRequest(url: URL(string: "\(testAPIBase)/test/startServer")!)
        request.httpMethod = "POST"
        addHarnessAuthHeader(&request)

        do {
            try runHarnessRequest(request)
        } catch {
            XCTFail("Harness startup failed: \(error)", file: file, line: line)
        }

        callback()
    }
    
    static func beforeEachTest(callback: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        SuperTokens.resetForTests()
        var beforeeachRequest = URLRequest(url: URL(string: "\(testAPIBase)/beforeeach")!)
        beforeeachRequest.httpMethod = "POST"
        addHarnessAuthHeader(&beforeeachRequest)

        do {
            try runHarnessRequest(beforeeachRequest)
        } catch {
            XCTFail("Harness /beforeeach failed: \(error)", file: file, line: line)
        }

        callback()
    }
    
    static func getTestingUrlSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = harnessTimeout
        config.timeoutIntervalForResource = harnessTimeout
        return URLSession(configuration: config)
    }
    
    internal static func startST(validity: Int = 3, refreshValidity: Double? = nil, disableAntiCSRF: Bool? = false, file: StaticString = #filePath, line: UInt = #line) {
        do {
            try startSTHelper(validity: validity, refreshValidity: refreshValidity, disableAntiCSRF: disableAntiCSRF)
        } catch {
            XCTFail("Harness /startst failed: \(error)", file: file, line: line)
        }
    }
    //
    private static func startSTHelper(validity: Int = 1, refreshValidity: Double? = nil, disableAntiCSRF: Bool? = false) throws {
        var request = URLRequest(url: URL(string: "\(testAPIBase)/startst")!)
        
        var json: [String: Any] = ["accessTokenValidity": validity, "enableAntiCsrf": !(disableAntiCSRF ?? false)]
        if let refreshValidity = refreshValidity {
            json["refreshValidity"] = refreshValidity
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        addHarnessAuthHeader(&request)
        request.httpBody = jsonData
        try runHarnessRequest(request)
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
    
    static func getLogoutAltRequest() -> URLRequest {
        let url = URL(string: "\(testAPIBase)/logout-alt")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    static func getLoginRequest_2_18() -> URLRequest {
        let url = URL(string: "\(testAPIBase)/login-2.18")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        
        let json: [String: Any] = [
            "userId": "supertokens-ios-tests",
            "payload": [
                "asdf": 1
            ]
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        return request
    }
    
    static func getFeatureFlags() throws -> NSDictionary {
        let url = URL(string: "\(testAPIBase)/featureFlags")
        let request = URLRequest(url: url!)
        let requestSemaphore = DispatchSemaphore(value: 0)
        
        var resultError: Error? = nil
        var flags: NSDictionary = [:]
        
        getTestingUrlSession().dataTask(with: request, completionHandler: {
            data, response, e in
            
            if e != nil {
                resultError = e
            } else {
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data!, options: []) as! NSDictionary
                    flags = jsonResponse
                } catch {
                    resultError = error
                }
            }
            
            requestSemaphore.signal()
            
        }).resume()
        
        _ = requestSemaphore.wait(timeout: .distantFuture)
        
        if resultError != nil {
            throw resultError!
        }
        
        return flags
    }
    
    static func checkIfV3AccessTokenIsSupported() throws -> Bool {
        var flags = try! getFeatureFlags()
        var v3Flag = flags["v3AccessToken"]
        
        if let _v3Flag: Bool = v3Flag as? Bool, _v3Flag {
            return true
        }
        
        return false
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
