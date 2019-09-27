//
//  SuperTokensNSURLConnection.swift
//  session
//
//  Created by Nemi Shah on 24/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

public class SuperTokensURLConnection {
    private static let lock = NSObject()
    
    public static func newTask(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) throws {
        if !SuperTokens.isInitCalled {
            throw SuperTokensError.illegalAccess("SuperTokens.init must be called before calling SuperTokensURLConnection.newRequest")
        }
        
        defer {
            let idRefreshToken = IdRefreshToken.getToken()
            if idRefreshToken == nil {
                AntiCSRF.removeToken()
            }
        }
        
        do {
            try makeRequest(request: request, completionHandler: completionHandler)
        }
    }
    
    private static func makeRequest(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) throws {
        let mutableCopy = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        let preRequestIdRefreshToken = IdRefreshToken.getToken()
        let antiCSRFToken = AntiCSRF.getToken(associatedIdRefreshToken: preRequestIdRefreshToken)
        if antiCSRFToken != nil {
            mutableCopy.addValue(antiCSRFToken!, forHTTPHeaderField: SuperTokensConstants.antiCSRFHeaderKey)
        }
        
        let newRequest = mutableCopy.copy() as! URLRequest
        let session = URLSession.shared
        session.dataTask(with: newRequest, completionHandler: { data, response, httpError in
            if (response as? HTTPURLResponse) != nil {
                let httpResponse = response as! HTTPURLResponse
                SuperTokensCookieHandler.saveIdRefreshFromCookies()
                
                if httpResponse.statusCode == SuperTokens.sessionExpiryStatusCode {
                    do {
                        print("Unauthorised")
                        try handleUnauthorised(preRequestIdRefreshToken: preRequestIdRefreshToken, completionHandler: {
                            retry in
                            
                            if !retry {
                                completionHandler(data, response, httpError)
                            } else {
                                try makeRequest(request: request, completionHandler: completionHandler)
                            }
                        })
                    } catch {
                        completionHandler(nil, nil, error)
                    }
                } else {
                    let antiCSRFFromResponse = httpResponse.allHeaderFields[SuperTokensConstants.antiCSRFHeaderKey]
                    if antiCSRFFromResponse != nil {
                        let idRefreshPostResponse = IdRefreshToken.getToken()
                        AntiCSRF.setToken(antiCSRFToken: antiCSRFFromResponse as! String, associatedIdRefreshToken: idRefreshPostResponse)
                    }
                    completionHandler(data, response, httpError)
                }
            }
            }).resume()
    }
    
    private static func handleUnauthorised(preRequestIdRefreshToken: String?, completionHandler: (Bool, Error?) throws -> Void) throws {
        if preRequestIdRefreshToken == nil {
            let idRefreshToken = IdRefreshToken.getToken()
            try completionHandler(idRefreshToken != nil, nil)
        }
        
        try onUnauthorisedResponse(refreshTokenEndpoint: SuperTokens.refreshTokenEndpoint!, preRequestIdRefreshToken: preRequestIdRefreshToken!, unathCompletionHandler: {
                unauthorisedResponse in
            
                if unauthorisedResponse.status == UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED {
                    try completionHandler(false, nil)
                    return;
                } else if unauthorisedResponse.status == UnauthorisedResponse.UnauthorisedStatus.API_ERROR {
                    try completionHandler(false, unauthorisedResponse.error!)
                }
                
                try completionHandler(true)
        })
    }
    
    private static func onUnauthorisedResponse(refreshTokenEndpoint: String, preRequestIdRefreshToken: String, unathCompletionHandler: @escaping (UnauthorisedResponse) -> Void) throws {
        objc_sync_enter(lock)
        let postLockIdRefresh = IdRefreshToken.getToken()
        if postLockIdRefresh == nil {
            unathCompletionHandler(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED))
        }
        
        if postLockIdRefresh != preRequestIdRefreshToken {
            unathCompletionHandler(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.RETRY))
        }
        
        let refreshUrl = URL(string: refreshTokenEndpoint)!
        var refreshRequest = URLRequest(url: refreshUrl)
        refreshRequest.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: refreshRequest, completionHandler: { data, response, error in
            
            print("Refresh response recieved")
            if (response as? HTTPURLResponse) != nil {
                print("Refresh response was nil")
                let httpResponse = response as! HTTPURLResponse
                SuperTokensCookieHandler.saveIdRefreshFromCookies()
                
                if httpResponse.statusCode != 200 {
                    unathCompletionHandler(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.API_ERROR))
                    return;
                }
                
                let idRefreshToken = IdRefreshToken.getToken()
                if idRefreshToken == nil {
                    unathCompletionHandler(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED))
                    return;
                }
                
                let antiCSRFFromResponse = httpResponse.allHeaderFields[SuperTokensConstants.antiCSRFHeaderKey]
                if antiCSRFFromResponse != nil {
                    AntiCSRF.setToken(antiCSRFToken: antiCSRFFromResponse as! String, associatedIdRefreshToken: idRefreshToken)
                }
                
                unathCompletionHandler(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED))
                objc_sync_exit(lock)
            }
            }).resume()
    }
}
