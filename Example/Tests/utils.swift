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
import SuperTokensSession

let testAPIBase = "http://127.0.0.1:8080/"
let refreshCounterAPIURL = "\(testAPIBase)refreshCounter"
let afterAPIURL = "\(testAPIBase)after"
let beforeEachAPIURL = "\(testAPIBase)beforeeach"
let startSTAPIURL = "\(testAPIBase)startst"
let refreshDeviceInfoAPIURL = "\(testAPIBase)refreshDeviceInfo"

internal func afterAPI(successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: afterAPIURL)
    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
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

internal func startST(validity: Int = 1, refreshValidity: Double? = nil, disableAntiCSRF: Bool? = false) {
    let semaphore = DispatchSemaphore(value: 0)
    startSTHelper(validity: validity, refreshValidity: refreshValidity, disableAntiCSRF: disableAntiCSRF, successCallback: {
        semaphore.signal()
    }) {
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
}

private func startSTHelper(validity: Int = 1, refreshValidity: Double? = nil, disableAntiCSRF: Bool? = false, successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: startSTAPIURL)
    var request = URLRequest(url: url!)
    
    var json: [String: Any] = ["accessTokenValidity": validity]
    if refreshValidity != nil {
        json = ["accessTokenValidity": validity, "refreshTokenValidity": refreshValidity!, "disableAntiCSRF": disableAntiCSRF!]
    }
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    request.httpMethod = "POST"
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
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

internal func beforeEachAPI(successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: beforeEachAPIURL)
    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
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

internal func getRefreshTokenCounter() -> Int {
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

internal func getRefreshTokenCounterUsingST() -> Int {
    let refreshCounterSemaphore = DispatchSemaphore(value: 0)
    var result = -1;
    getRefreshTokenCounterHelperUsingST(successCallback: {
        counter in
        result = counter
        refreshCounterSemaphore.signal()
    }, failureCallback: {
        refreshCounterSemaphore.signal()
    })
    _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
    return result;
}

private func getRefreshTokenCounterHelper(successCallback: @escaping (Int) -> Void, failureCallback: @escaping () -> Void) {
    let refreshCounterSempahore = DispatchSemaphore(value: 0)
    let url = URL(string: refreshCounterAPIURL)
    let request = URLRequest(url: url!)
    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
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

private func getRefreshTokenCounterHelperUsingST(successCallback: @escaping (Int) -> Void, failureCallback: @escaping () -> Void) {
    let refreshCounterSempahore = DispatchSemaphore(value: 0)
    let url = URL(string: refreshCounterAPIURL)
    let request = URLRequest(url: url!)
    SuperTokensURLSession.dataTask(request: request, completionHandler: { data, response, error in
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
    _ = refreshCounterSempahore.wait(timeout: .distantFuture)
}

internal func getRefreshAPIDeviceInfo() -> NSDictionary? {
    let refreshCounterSemaphore = DispatchSemaphore(value: 0)
    var result: NSDictionary? = nil;
    getRefreshAPIDeviceInfoHelper(successCallback: {
        json in
        result = json
        refreshCounterSemaphore.signal()
    }, failureCallback: {
        refreshCounterSemaphore.signal()
    })
    _ = refreshCounterSemaphore.wait(timeout: DispatchTime.distantFuture)
    return result;
}

private func getRefreshAPIDeviceInfoHelper(successCallback: @escaping (NSDictionary) -> Void, failureCallback: @escaping () -> Void) {
    let refreshCounterSempahore = DispatchSemaphore(value: 0)
    let url = URL(string: refreshDeviceInfoAPIURL)
    let request = URLRequest(url: url!)
    let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
        
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
                successCallback(jsonResponse)
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
