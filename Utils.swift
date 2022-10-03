//
//  Utils.swift
//  SuperTokensSession
//
//  Created by Nemi Shah on 30/09/22.
//

import Foundation

class NormalisedInputType {
    var apiDomain: String
    var apiBasePath: String
    var sessionExpiredStatusCode: Int
    var cookieDomain: String?
    
    init(apiDomain: String, apiBasePath: String, sessionExpiredStatusCode: Int, cookieDomain: String?) {
        self.apiDomain = apiDomain
        self.apiBasePath = apiBasePath
        self.sessionExpiredStatusCode = sessionExpiredStatusCode
        self.cookieDomain = cookieDomain
    }
    
    internal static func sessionScopeHelper(sessionScope: String) throws -> String {
        var trimmedSessionScope = sessionScope.trim()
        
        if trimmedSessionScope.starts(with: ".") {
            trimmedSessionScope = trimmedSessionScope.substring(fromIndex: 1)
        }
        
        if !trimmedSessionScope.starts(with: "http://") && !trimmedSessionScope.starts(with: "https://") {
            trimmedSessionScope = "http://" + trimmedSessionScope
        }
        
        do {
            guard let url: URL = URL(string: trimmedSessionScope), let host: String = url.host else {
                throw SDKFailableError.failableError
            }
            
            trimmedSessionScope = host
            
            if trimmedSessionScope.starts(with: ".") {
                trimmedSessionScope = trimmedSessionScope.substring(fromIndex: 1)
            }
            
            return trimmedSessionScope
        } catch {
            throw SuperTokensError.initError(message: "Please provide a valid sessionScope")
        }
    }
    
    internal static func normaliseSessionScopeOrThrowError(sessionScope: String) throws -> String {
        let noDotNormalised = try sessionScopeHelper(sessionScope: sessionScope)
        
        if noDotNormalised == "localhost" || Utils.isIpAddress(input: noDotNormalised) {
            return noDotNormalised
        }
        
        if sessionScope.starts(with: ".") {
            return "." + noDotNormalised
        }
        
        return noDotNormalised
    }
    
    internal static func normaliseInputType(apiDomain: String, apiBasePath: String?, sessionExpiredStatusCode: Int?, cookieDomain: String?) throws -> NormalisedInputType {
        let _apiDomain = try NormalisedURLDomain(url: apiDomain)
        var _apiBasePath = try NormalisedURLPath(input: "/auth")
        
        if apiBasePath != nil {
            _apiBasePath = try NormalisedURLPath(input: apiBasePath!)
        }
        
        var _sessionExpiredStatusCode: Int = 401
        if sessionExpiredStatusCode != nil {
            _sessionExpiredStatusCode = sessionExpiredStatusCode!
        }
        
        var _cookieDomain: String? = nil
        if cookieDomain != nil {
            _cookieDomain = try normaliseSessionScopeOrThrowError(sessionScope: cookieDomain!)
        }
        
        return NormalisedInputType(apiDomain: _apiDomain.getAsStringDangerous(), apiBasePath: _apiBasePath.getAsStringDangerous(), sessionExpiredStatusCode: _sessionExpiredStatusCode, cookieDomain: _cookieDomain)
    }
}

internal class Utils {
    internal static func shouldDoInterception(toCheckURL: String, apiDomain: String, cookieDomain: String?) throws -> Bool {
        let _toCheckURL: String = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: toCheckURL)
        var _apiDomain: String = apiDomain
        
        guard let urlObj: URL = URL(string: _toCheckURL), let hostname: String = urlObj.host else {
            throw SDKFailableError.failableError
        }
        
        var domain = hostname
        
        if cookieDomain == nil {
            domain = urlObj.port == nil ? domain : domain + ":" + "\(urlObj.port!)"
            _apiDomain = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: apiDomain)
            
            guard let apiUrlObj: URL = URL(string: _apiDomain), let apiHostName: String = apiUrlObj.host else {
                throw SDKFailableError.failableError
            }
            
            return domain == (apiUrlObj.port == nil ? apiHostName : apiHostName + ":" + "\(apiUrlObj.port!)")
        } else {
            var normalisedCookieDomain = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: cookieDomain!)
            
            if cookieDomain!.split(separator: ":").count > 1 {
                let portString: String = String(cookieDomain!.split(separator: ":")[cookieDomain!.split(separator: ":").count - 1])
                
                if portString.isNumeric {
                    normalisedCookieDomain = normalisedCookieDomain + ":" + portString
                    domain = urlObj.port == nil ? domain : domain + ":" + "\(urlObj.port!)"
                }
            }
            
            if cookieDomain!.starts(with: ".") {
                return ("." + domain).hasSuffix(normalisedCookieDomain)
            } else {
                return domain == normalisedCookieDomain
            }
        }
    }
    
    internal static func isIpAddress(input: String) -> Bool {
        let regex: String = "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        
        return input.matches(regex: regex)
    }
}
