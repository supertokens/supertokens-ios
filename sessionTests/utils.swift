//
//  utils.swift
//  sessionTests
//
//  Created by Rishabh Poddar on 10/12/2019.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

let testAPIBase = "http://127.0.0.1:8080/"
let refreshCounterAPIURL = "\(testAPIBase)refreshCounter"
let afterAPIURL = "\(testAPIBase)after"
let beforeEachAPIURL = "\(testAPIBase)beforeeach"
let startSTAPIURL = "\(testAPIBase)startst"

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

internal func startST(validity: Int = 1) {
    let semaphore = DispatchSemaphore(value: 0)
    startSTHelper(validity: validity, successCallback: {
        semaphore.signal()
    }) {
        semaphore.signal()
    }
    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
}

private func startSTHelper(validity: Int = 1, successCallback: @escaping () -> Void, failureCallback: @escaping () -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: startSTAPIURL)
    var request = URLRequest(url: url!)
    
    let json: [String: Any] = ["accessTokenValidity": validity]
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
