//
//  SuperTokens.swift
//  session
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

public class SuperTokens {
    static var sessionExpiryStatusCode = 440
    static var isInitCalled = false
    static var apiDomain: String? = nil
    static var refreshTokenEndpoint: String? = nil
    
    public static func `init`(refreshTokenEndpoint: String, sessionExpiryStatusCode: Int? = nil) throws {
        if SuperTokens.isInitCalled {
            return;
        }
        
        SuperTokens.refreshTokenEndpoint = refreshTokenEndpoint
        if sessionExpiryStatusCode != nil {
            SuperTokens.sessionExpiryStatusCode = sessionExpiryStatusCode!
        }
        
        SuperTokens.apiDomain = try SuperTokens.getApiDomain(refreshTokenEndpoint: refreshTokenEndpoint)
        SuperTokens.isInitCalled = true
    }
    
    private static func getApiDomain(refreshTokenEndpoint: String) throws -> String {
        if refreshTokenEndpoint.starts(with: "http://") || refreshTokenEndpoint.starts(with: "https://") {
            let splitArray = refreshTokenEndpoint.split(separator: "/").map(String.init)
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
    
    public static func sessionPossiblyExists() -> Bool {
        let token = IdRefreshToken.getToken()
        return token != nil
    }
}
