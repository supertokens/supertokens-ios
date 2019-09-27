//
//  sessionTests.swift
//  sessionTests
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import XCTest
@testable import session

class sessionTests: XCTestCase {
    static let testAPIBase = "http://127.0.0.1:8080/api/"
    let refreshTokenAPIURL = "\(testAPIBase)refreshtoken"
    let loginAPIURL = "\(testAPIBase)login"
    let resetAPIURL = "\(testAPIBase)testReset"
    let refreshCounterAPIURL = "\(testAPIBase)testRefreshCounter"
    let userInfoAPIURL = "\(testAPIBase)userInfo"
    let sessionExpiryCode = 440

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        SuperTokens.isInitCalled = false
    }

    func resetAccessTokenValidity(validity: Int, failureCallback: @escaping () -> Void) {
        let resetExpectation = expectation(description: "Reset API")
        let url = URL(string: resetAPIURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/json; utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("\(validity)", forHTTPHeaderField: "atValidity")
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            defer {
                resetExpectation.fulfill()
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                if httpResponse.statusCode != 200 {
                    failureCallback()
                    return
                }
            } else {
                failureCallback()
            }
        })
        task.resume()
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func getRefreshTokenCounter(successCallback: @escaping (Int) -> Void, failureCallback: @escaping () -> Void) {
        let refreshCounterExpectation = expectation(description: "Refresh Counter")
        let url = URL(string: refreshCounterAPIURL)
        let request = URLRequest(url: url!)
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            
            defer {
                refreshCounterExpectation.fulfill()
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
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testResetAPI() {
        getRefreshTokenCounter(successCallback: {
            counter in
            print("SUCCESS: \(counter)")
        }, failureCallback: {
            print("failed")
        })
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
