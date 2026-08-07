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

public enum EventType {
    case SIGN_OUT
    case REFRESH_SESSION
    case SESSION_CREATED
    case ACCESS_TOKEN_PAYLOAD_UPDATED
    case UNAUTHORISED
}

public enum APIAction {
    case SIGN_OUT
    case REFRESH_SESSION
}

public class SuperTokens {
    static var sessionExpiryStatusCode = 401
    static var isInitCalled = false
    static var refreshTokenUrl: String = ""
    static var signOutUrl: String = ""
    static var rid: String = ""
    static var config: NormalisedInputType? = nil
    
    
    internal static func resetForTests() {
        _ = FrontToken.removeToken()
        _ = AntiCSRF.removeToken()
        _ = SDKStorage.clearSessionStorage()
        SuperTokens.isInitCalled = false
    }
    
    public static func initialize(apiDomain: String, apiBasePath: String? = nil, sessionExpiredStatusCode: Int? = nil, sessionTokenBackendDomain: String? = nil,  maxRetryAttemptsForSessionRefresh: Int? = nil, tokenTransferMethod: SuperTokensTokenTransferMethod? = nil, userDefaultsSuiteName: String? = nil, keychainAccessGroup: String? = nil, eventHandler: ((EventType) -> Void)? = nil, preAPIHook: ((APIAction, URLRequest) -> URLRequest)? = nil, postAPIHook: ((APIAction, URLRequest, URLResponse?) -> Void)? = nil) throws {
        if SuperTokens.isInitCalled {
            return;
        }
        
        SuperTokens.config = try NormalisedInputType.normaliseInputType(apiDomain: apiDomain, apiBasePath: apiBasePath, sessionExpiredStatusCode: sessionExpiredStatusCode, maxRetryAttemptsForSessionRefresh: maxRetryAttemptsForSessionRefresh, sessionTokenBackendDomain: sessionTokenBackendDomain, tokenTransferMethod: tokenTransferMethod, eventHandler: eventHandler, preAPIHook: preAPIHook, postAPIHook: postAPIHook, userDefaultsSuiteName: userDefaultsSuiteName, keychainAccessGroup: keychainAccessGroup)
        
        guard let _config: NormalisedInputType = SuperTokens.config else {
            throw SuperTokensError.initError(message: "Error initialising SuperTokens")
        }
        
        SuperTokens.refreshTokenUrl = _config.apiDomain + _config.apiBasePath + "/session/refresh"
        SuperTokens.signOutUrl = _config.apiDomain + _config.apiBasePath + "/signout"
        SuperTokens.rid = "session"
        if _config.userDefaultsSuiteName != nil && _config.keychainAccessGroup == nil {
            print("SuperTokens: userDefaultsSuiteName only migrates legacy UserDefaults values. Use keychainAccessGroup to share sessions with app extensions after migration.")
        }

        guard SDKStorage.configure(userDefaultsSuiteName: _config.userDefaultsSuiteName, keychainAccessGroup: _config.keychainAccessGroup, apiDomain: _config.apiDomain, apiBasePath: _config.apiBasePath) else {
            throw SuperTokensError.initError(message: "Could not access Keychain with the configured access group")
        }
        SuperTokens.isInitCalled = true
    }
    
    public static func doesSessionExist() -> Bool {
        let tokenInfo = FrontToken.getToken()
        
        if tokenInfo == nil {
            return false
        }
        
        let currentTimeInMillis: Int = Int(Date().timeIntervalSince1970 * 1000)
        
        if let accessTokenExpiry: Int = tokenInfo!["ate"] as? Int, accessTokenExpiry < currentTimeInMillis {
            let executionSemaphore = DispatchSemaphore(value: 0)
            var shouldRetry: Bool = false
            var error: Error?
            let preRequestLocalSessionState = Utils.getLocalSessionState()
            
            SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: preRequestLocalSessionState, callback: { unauthResponse in
                
                if unauthResponse.status == .API_ERROR {
                    error = unauthResponse.error
                }
                
                shouldRetry = unauthResponse.status == .RETRY
                executionSemaphore.signal()
                
            })
            
            executionSemaphore.wait()
            
            // Here we dont throw the error and instead return false, because
            // otherwise users would have to use a try catch just to call doesSessionExist
            if error != nil {
                return false
            }
            
            return shouldRetry
        }
        
        return true
    }
    
    public static func signOut(completionHandler: @escaping (Error?) -> Void) {
        if !doesSessionExist() {
            SuperTokens.config!.eventHandler(.SIGN_OUT)
            completionHandler(nil)
            return
        }
        
        guard let url: URL = URL(string: SuperTokens.signOutUrl) else {
            completionHandler(SuperTokensError.initError(message: "Please provide a valid apiDomain and apiBasePath"))
            return
        }
        
        let sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.protocolClasses?.insert(SuperTokensURLProtocol.self, at: 0)
        let customSession = URLSession(configuration: sessionConfiguration)
        
        var signOutRequest = URLRequest(url: url)
        signOutRequest.httpMethod = "POST"
        signOutRequest.addValue(SuperTokens.rid, forHTTPHeaderField: "rid")
        
        signOutRequest = SuperTokens.config!.preAPIHook(.SIGN_OUT, signOutRequest)
        
        let executionSemaphore = DispatchSemaphore(value: 0)
        
        customSession.dataTask(with: signOutRequest, completionHandler: {
            data, response, error in

            if let error = error {
                completionHandler(error)
                executionSemaphore.signal()
                return
            }
            
            if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == SuperTokens.config!.sessionExpiredStatusCode {
                    // refresh must have already sent session expiry event
                    executionSemaphore.signal()
                    return
                }
                
                if httpResponse.statusCode >= 300 {
                    completionHandler(SuperTokensError.apiError(message: "Sign out failed with response code \(httpResponse.statusCode)"))
                    executionSemaphore.signal()
                    return
                }
                
                SuperTokens.config!.postAPIHook(.SIGN_OUT, signOutRequest, response)
                
                if let _data: Data = data, let jsonResponse: SignOutResponse = try? JSONDecoder().decode(SignOutResponse.self, from: _data) {
                    if jsonResponse.status == "GENERAL_ERROR" {
                        completionHandler(SuperTokensError.generalError(message: jsonResponse.message!))
                        executionSemaphore.signal()
                    } else {
                        completionHandler(nil)
                        executionSemaphore.signal()
                    }
                } else {
                    completionHandler(SuperTokensError.apiError(message: "Invalid sign out response"))
                    executionSemaphore.signal()
                }
            } else {
                completionHandler(nil)
                executionSemaphore.signal()
            }
            
            // we do not send an event here since it's triggered in fireSessionUpdateEventsIfNecessary.
        }).resume()
    }
    
    public static func attemptRefreshingSession() throws -> Bool {
        if !SuperTokens.isInitCalled {
            throw SuperTokensError.initError(message: "Init function not called")
        }
        
        let preRequestLocalSessionState = Utils.getLocalSessionState()
        var error: Error?
        let executionSemaphore = DispatchSemaphore(value: 0)
        var shouldRetry: Bool = false
        
        SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: preRequestLocalSessionState, callback: {
            unauthResponse in
            
            if unauthResponse.status == .API_ERROR {
                error = unauthResponse.error
            }
            
            shouldRetry = unauthResponse.status == .RETRY
            executionSemaphore.signal()
        })
        
        executionSemaphore.wait()
        
        if error != nil {
            throw error!
        }
        
        return shouldRetry
    }
    
    public static func getUserId() throws -> String {
        guard let frontToken: [String: Any] = FrontToken.getToken(), let userId: String = frontToken["uid"] as? String else {
            throw SuperTokensError.illegalAccess(message: "No session exists")
        }
        
        return userId
    }
    
    public static func getAccessTokenPayloadSecurely() throws -> [String: Any] {
        guard let frontToken: [String: Any] = FrontToken.getToken(), let accessTokenExpiry: Int = frontToken["ate"] as? Int, let userPayload: [String: Any] = frontToken["up"] as? [String: Any] else {
            throw SuperTokensError.illegalAccess(message: "No session exists")
        }
        
        if accessTokenExpiry < Int(Date().timeIntervalSince1970 * 1000) {
            let retry = try SuperTokens.attemptRefreshingSession()
            
            if retry {
                return try getAccessTokenPayloadSecurely()
            } else {
                throw SuperTokensError.illegalAccess(message: "Could not refresh session")
            }
        }
        
        return userPayload
    }
    
    public static func getAccessToken() -> String? {
        if doesSessionExist() {
            return Utils.getTokenForHeaderAuth(tokenType: .access)
        }

        return nil
    }

    /// Returns the current raw stored refresh token, or nil. No network, regardless
    /// of session validity.
    public static func getRefreshToken() -> String? {
        return Utils.getTokenForHeaderAuth(tokenType: .refresh)
    }

    /// Returns the current raw front token (base64-encoded JSON), or nil. No network.
    public static func getFrontToken() -> String? {
        return SDKStorage.get(SDKStorage.frontTokenKey)
    }

    /// Returns the current anti-CSRF token, or nil. No network.
    public static func getAntiCSRF() -> String? {
        return SDKStorage.get(SDKStorage.antiCSRFKey)
    }

    /// A front token is well-formed if it is base64-encoded UTF8 JSON containing
    /// `uid` (String), `ate` (Int), and `up` ([String: Any]). Does not delegate to
    /// `FrontToken.parseFrontToken`, which force-unwraps and would crash on a
    /// malformed value; this is a pure, side-effect-free check.
    private static func isWellFormedFrontToken(_ frontToken: String) -> Bool {
        guard let decodedData = Data(base64Encoded: frontToken),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let jsonData = decodedString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
              let json = jsonObject as? [String: Any] else {
            return false
        }

        guard json["uid"] is String,
              json["ate"] is Int,
              json["up"] is [String: Any] else {
            return false
        }

        return true
    }

    /// Installs a session from tokens obtained OUT OF BAND (e.g. a WKWebView / Hub
    /// magic-link flow) whose responses never traversed `SuperTokensURLProtocol`.
    ///
    /// Reuses the SDK's own validated write path — identical order and rollback to
    /// `saveTokenFromHeaders` — so the front-token in-memory cache, the anti-CSRF
    /// timestamp association, and the last-access-token-update stamp all stay
    /// coherent. No network call.
    ///
    /// The write sequence is serialized on `SuperTokensURLProtocol`'s refresh
    /// barrier queue, so an out-of-band install is atomic with respect to an
    /// in-flight 401 refresh. As a result the call may block briefly while a
    /// refresh is in flight; do not call it on the main thread.
    ///
    /// `frontToken` is validated (base64-decodable JSON containing `uid`/`ate`/`up`)
    /// before anything is written; a malformed value (including the `"remove"`
    /// sentinel) is rejected rather than stored. Validation is structural only:
    /// tokens are trusted as provided and are not cryptographically verified (a
    /// forged access token is rejected server-side on the next request).
    ///
    /// - Returns: `true` on success. Returns `false` without writing anything if
    ///   `initialize()` has not been called, if `accessToken`/`refreshToken`/
    ///   `frontToken` is empty, or if `frontToken` is malformed. On any write
    ///   failure the session storage is fully rolled back (`clearSessionStorage`)
    ///   and `false` is returned.
    @discardableResult
    public static func installSession(accessToken: String,
                                      refreshToken: String,
                                      frontToken: String,
                                      antiCSRFToken: String? = nil) -> Bool {
        guard SuperTokens.isInitCalled else { return false }
        guard !accessToken.isEmpty, !refreshToken.isEmpty, !frontToken.isEmpty else { return false }
        guard isWellFormedFrontToken(frontToken) else { return false }

        // installSession is a public entry point never called from within this
        // queue's own work items, so this sync barrier cannot deadlock.
        return SuperTokensURLProtocol.readWriteDispatchQueue.sync(flags: .barrier) {
            // Intentionally does NOT fire a session-lifecycle event; callers own semantic events.
            guard Utils.setToken(tokenType: .refresh, value: refreshToken) else {
                SDKStorage.clearSessionStorage(); return false
            }
            guard Utils.setToken(tokenType: .access, value: accessToken) else {
                SDKStorage.clearSessionStorage(); return false
            }
            guard FrontToken.setItem(frontToken: frontToken) else {
                SDKStorage.clearSessionStorage(); return false
            }
            if let antiCSRFToken, !antiCSRFToken.isEmpty {
                let lastUpdate = Utils.getLocalSessionState().lastAccessTokenUpdate
                guard AntiCSRF.setToken(antiCSRFToken: antiCSRFToken,
                                        associatedAccessTokenUpdate: lastUpdate) else {
                    SDKStorage.clearSessionStorage(); return false
                }
            } else {
                // No anti-CSRF token for this session: clear out any stale token left
                // over from a previous session rather than silently inheriting it.
                guard AntiCSRF.removeToken() else {
                    SDKStorage.clearSessionStorage(); return false
                }
            }
            return true
        }
    }

    /// Clears all local session state — tokens plus the `FrontToken` / `AntiCSRF`
    /// in-memory caches — WITHOUT a network `/signout`. Use when a caller has torn
    /// down the session out of band and needs the SDK's local view invalidated.
    ///
    /// Serialized on the same barrier queue as `installSession` and the SDK's
    /// refresh flow, so a local clear is atomic with respect to an in-flight
    /// refresh. Never called from within that queue's own work items, so this
    /// sync barrier cannot deadlock. May block briefly while a refresh is in
    /// flight; do not call it on the main thread.
    ///
    /// Intentionally does NOT fire a session-lifecycle event; callers own semantic events.
    @discardableResult
    public static func clearSessionLocally() -> Bool {
        return SuperTokensURLProtocol.readWriteDispatchQueue.sync(flags: .barrier) {
            FrontToken.removeToken()
        }
    }
}
