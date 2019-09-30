//
//  SuperTokensURLSession.swift
//  session
//
//  Created by Nemi Shah on 26/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

public class SuperTokensURLSession {
    private static let readWriteDispatchQueue = DispatchQueue(label: "io.supertokens.session.readwrite", attributes: .concurrent)
    
    public static func newTask(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        if !SuperTokens.isInitCalled {
            completionHandler(nil, nil, SuperTokensError.illegalAccess("SuperTokens.init must be called before calling SuperTokensURLSession.newTask"))
            return
        }
        
        readWriteDispatchQueue.async {
            makeRequest(request: request, completionHandler: completionHandler)
        }
    }
    
    private static func makeRequest(request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        let preRequestIdRefresh = IdRefreshToken.getToken()
        let antiCSRF = AntiCSRF.getToken(associatedIdRefreshToken: preRequestIdRefresh)
        if antiCSRF != nil {
            mutableRequest.addValue(antiCSRF!, forHTTPHeaderField: SuperTokensConstants.antiCSRFHeaderKey)
        }
        
        let apiRequest = mutableRequest.copy() as! URLRequest
        let apiTask = URLSession.shared.dataTask(with: apiRequest, completionHandler: { data, response, httpError in
            
            defer {
                let idRefreshToken = IdRefreshToken.getToken()
                if idRefreshToken == nil {
                    AntiCSRF.removeToken()
                }
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                SuperTokensCookieHandler.saveIdRefreshFromCookies()
                if httpResponse.statusCode == SuperTokens.sessionExpiryStatusCode {
                    handleUnauthorised(preRequestIdRefresh: preRequestIdRefresh, retryCallback: { shouldRetry, error in
                        
                        if error != nil {
                            completionHandler(nil, nil, error)
                            return
                        }
                        
                        if shouldRetry {
                            makeRequest(request: request, completionHandler: completionHandler)
                        } else {
                            completionHandler(data, response, error)
                        }
                    })
                } else {
                    let antiCSRFFromResponse = httpResponse.allHeaderFields[SuperTokensConstants.antiCSRFHeaderKey]
                    if antiCSRFFromResponse != nil {
                        let idRefreshPostResponse = IdRefreshToken.getToken()
                        AntiCSRF.setToken(antiCSRFToken: antiCSRFFromResponse as! String, associatedIdRefreshToken: idRefreshPostResponse)
                    }
                    completionHandler(data, response, httpError)
                }
            } else {
                completionHandler(data, response, httpError)
            }
        })
        apiTask.resume()
    }
    
    private static func handleUnauthorised(preRequestIdRefresh: String?, retryCallback: @escaping (Bool, Error?) -> Void) {
        readWriteDispatchQueue.async(flags: .barrier) {
            if preRequestIdRefresh == nil {
                readWriteDispatchQueue.async {
                    let idRefreshFromStorage = IdRefreshToken.getToken()
                    retryCallback(idRefreshFromStorage != nil, nil)
                }
                return
            }
            
            onUnauthorisedResponse(refreshTokenEndpoint: SuperTokens.refreshTokenEndpoint!, preRequestIdRefresh: preRequestIdRefresh!, unauthorisedCallback: {
                unauthorisedResponse in
                
                if unauthorisedResponse.status == UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED {
                    readWriteDispatchQueue.async {
                        retryCallback(false, nil)
                    }
                    return
                } else if unauthorisedResponse.status == UnauthorisedResponse.UnauthorisedStatus.API_ERROR {
                    readWriteDispatchQueue.async {
                        retryCallback(false, unauthorisedResponse.error)
                    }
                    return
                }
                
                readWriteDispatchQueue.async {
                    retryCallback(true, nil)
                }
            })
        }
    }
    
    private static func onUnauthorisedResponse(refreshTokenEndpoint: String, preRequestIdRefresh: String, unauthorisedCallback: @escaping (UnauthorisedResponse) -> Void) {
        let postLockIdRefresh = IdRefreshToken.getToken()
        if postLockIdRefresh == nil {
            unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED))
            return
        }
        
        if postLockIdRefresh != preRequestIdRefresh {
            unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.RETRY))
            return;
        }
        
        let refreshUrl = URL(string: refreshTokenEndpoint)!
        var refreshRequest = URLRequest(url: refreshUrl)
        refreshRequest.httpMethod = "POST"
        let semaphore = DispatchSemaphore(value: 0)
        
        let refreshTask = URLSession.shared.dataTask(with: refreshRequest, completionHandler: { data, response, error in
            
            defer {
                semaphore.signal()
            }
            
            if response as? HTTPURLResponse != nil {
                let httpResponse = response as! HTTPURLResponse
                SuperTokensCookieHandler.saveIdRefreshFromCookies()
                if httpResponse.statusCode != 200 {
                    unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.API_ERROR, error: SuperTokensError.apiError("Refresh API returned with status code: \(httpResponse.statusCode)")))
                    return
                }
                
                let idRefreshToken = IdRefreshToken.getToken()
                if idRefreshToken == nil {
                    unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.SESSION_EXPIRED))
                    return
                }
                
                let antiCSRFFromResponse = httpResponse.allHeaderFields[SuperTokensConstants.antiCSRFHeaderKey]
                if antiCSRFFromResponse != nil {
                    AntiCSRF.setToken(antiCSRFToken: antiCSRFFromResponse as! String, associatedIdRefreshToken: idRefreshToken)
                }
                
                unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.RETRY))
            } else {
                unauthorisedCallback(UnauthorisedResponse(status: UnauthorisedResponse.UnauthorisedStatus.API_ERROR, error: error))
            }
        })
        refreshTask.resume()
        semaphore.wait()
    }
    
    public static func attemptRefreshingSession(completionHandler: @escaping (Bool, Error?) -> Void) {
        if !SuperTokens.isInitCalled {
            completionHandler(false, SuperTokensError.illegalAccess("SuperTokens.init must be called before calling SuperTokensURLSession.attemptRefreshingSession"))
            return
        }
        
        readWriteDispatchQueue.async {
            let preRequestIdRefresh = IdRefreshToken.getToken()
            handleUnauthorised(preRequestIdRefresh: preRequestIdRefresh, retryCallback: {
                result, error in
                
                defer {
                    let idRefreshToken = IdRefreshToken.getToken()
                    if idRefreshToken == nil {
                        AntiCSRF.removeToken()
                    }
                }
                
                if error != nil {
                    completionHandler(false, error!)
                    return
                }
                
                completionHandler(result, nil)
            })
        }
    }
}
