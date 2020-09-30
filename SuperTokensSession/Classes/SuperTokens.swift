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

public class SuperTokens: NSObject {
    static var sessionExpiryStatusCode = 401
    static var isInitCalled = false
    static var apiDomain: String? = nil
    static var refreshTokenEndpoint: String? = nil
    static var refreshAPICustomHeaders: NSDictionary = NSDictionary()
    

    @objc public static func initialise(refreshTokenEndpoint: String, sessionExpiryStatusCode: Int, refreshAPICustomHeaders: NSDictionary = NSDictionary()) throws {
        if SuperTokens.isInitCalled {
            return;
        }
        
        SuperTokens.refreshTokenEndpoint = refreshTokenEndpoint
        SuperTokens.refreshAPICustomHeaders = refreshAPICustomHeaders
        SuperTokens.sessionExpiryStatusCode = sessionExpiryStatusCode
        
        SuperTokens.apiDomain = try SuperTokens.getApiDomain(refreshTokenEndpoint: refreshTokenEndpoint)
        SuperTokens.isInitCalled = true
    }
    
    @objc public static func initialise(refreshTokenEndpoint: String, refreshAPICustomHeaders: NSDictionary = NSDictionary()) throws {
        try SuperTokens.initialise(refreshTokenEndpoint:refreshTokenEndpoint, sessionExpiryStatusCode:SuperTokens.sessionExpiryStatusCode, refreshAPICustomHeaders:refreshAPICustomHeaders)
    }
    
    private static func getApiDomain(refreshTokenEndpoint: String) throws -> String {
        guard var urlComponents = URLComponents(string: refreshTokenEndpoint) else {
            throw SuperTokensError.invalidURL("Invalid URL provided for refresh token endpoint")
        }
        if urlComponents.path.isEmpty || urlComponents.path == "/" {
            urlComponents.path = "/session/refresh"
        }
        guard let endpoint = urlComponents.string else {
            throw SuperTokensError.invalidURL("Invalid URL provided for refresh token endpoint")
        }
        if endpoint.starts(with: "http://") || endpoint.starts(with: "https://") {
            let splitArray = endpoint.split(separator: "/").map(String.init)
            if splitArray.count < 3 {
                throw SuperTokensError.invalidURL("Invalid URL provided for refresh token endpoint")
            }
            var apiDomainArray: [String] = []
            for index in (0...2) {
                apiDomainArray.append(splitArray[index])
            }
            return apiDomainArray.joined(separator: "/")
        } else {
            throw SuperTokensError.invalidURL("Refresh token endpoint must start with http or https")
        }
    }
    
    @objc public static func doesSessionExist() -> Bool {
        let token = IdRefreshToken.getToken()
        return token != nil
    }
}
