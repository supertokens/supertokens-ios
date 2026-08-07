//
//  SuperTokensURLProtocol.swift
//  SuperTokensSession
//
//  Created by Nemi Shah on 30/09/22.
//

import Foundation

public class SuperTokensURLProtocol: URLProtocol {
    private static let readWriteDispatchQueue = DispatchQueue(label: "io.supertokens.session.readwrite", attributes: .concurrent)
    private static let refreshStateQueue = DispatchQueue(label: "io.supertokens.session.refresh")
    private static let refreshApplicationCallbackKey = "io.supertokens.session.refresh.application-callback"
    private static var refreshInProgress = false
    private static var refreshEpoch: UInt64 = 0
    private static var refreshCallbacks: [(UnauthorisedResponse) -> Void] = []
    private var sessionRefreshAttempts = 0
    
    // Refer to comment in makeRequest to know why this is needed
    private var requestForRetry: NSMutableURLRequest? = nil
    
    override public init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    public override class func canInit(with request: URLRequest) -> Bool {
        if !SuperTokens.isInitCalled {
            // We cannot throw in this function because that would be an invalid override
            // In this case we need to rely on printing instead
            print("SuperTokens Error: SuperTokens.init has not been called")
            return false
        }
        
        // We only return true if we will be intercepting this request,
        // otherwise let normal execution continue
        //
        // NOTE: For iOS we dont check whether the request is being made for refreshing
        // because we use a custom URL session object so this protocol never gets called
        do {
            let doNotDoInterception = !(try Utils.shouldDoInterception(toCheckURL: request.url!.absoluteString, apiDomain: SuperTokens.config!.apiDomain, cookieDomain: SuperTokens.config!.sessionTokenBackendDomain))
            
            if !doNotDoInterception {
                // Returning true means that URLSession will use this class when making the request
                // Note: The system tries to call this function for all registered classes in order of registration
                return true
            }
            
        } catch {
            // No-op
        }
        
        // Returning false means the iOS will not use this class for this request
        return false
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        // we have a read write lock here. We take a read lock while making a request and a write lock while refreshing
        // because if we dno't do that, then there may be a race condition where we may read a new id refresh token from storage
        // but the cookies may still be the older ones.
        SuperTokensURLProtocol.readWriteDispatchQueue.async {
            self.makeRequest()
        }
    }
    
    private func removeAuthHeaderIfMatchesLocalToken(_mutableRequest: NSMutableURLRequest) -> NSMutableURLRequest {
        // .value is case insensitive
        if let originalAuthorizationHeader = _mutableRequest.value(forHTTPHeaderField: "Authorization") {
            let accessToken = Utils.getTokenForHeaderAuth(tokenType: .access)
            let refreshToken = Utils.getTokenForHeaderAuth(tokenType: .refresh)
            
            if accessToken != nil && refreshToken != nil && originalAuthorizationHeader == "Bearer \(accessToken!)" {
                // Removing headers from a request is not case insensitive
                _mutableRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                _mutableRequest.setValue(nil, forHTTPHeaderField: "authorization")
            }
        }
        
        return _mutableRequest
    }
    
    func makeRequest() {
        var mutableRequest = (self.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        var didAddAuthorizationHeader = false
        
        // When this function is called for retrying we cannot use the global request
        // because that will not have the modified headers
        if requestForRetry != nil {
            mutableRequest = requestForRetry!
            requestForRetry = nil
        }
        
        let sessionSnapshot = SessionStateCoordinator.requestSnapshot { () -> LocalSessionState in
            mutableRequest = removeAuthHeaderIfMatchesLocalToken(_mutableRequest: mutableRequest)

            let localSessionState = Utils.getLocalSessionState()

            if localSessionState.status == .EXISTS {
                let antiCSRF = AntiCSRF.getToken(associatedAccessTokenUpdate: localSessionState.lastAccessTokenUpdate!)
                if antiCSRF != nil {
                    mutableRequest.setValue(antiCSRF!, forHTTPHeaderField: SuperTokensConstants.antiCSRFHeaderKey)
                }
            }

            if mutableRequest.value(forHTTPHeaderField: "rid") == nil {
                mutableRequest.addValue("anti-csrf", forHTTPHeaderField: "rid")
            }

            let tokenTransferMethod = SuperTokens.config!.tokenTransferMethod
            mutableRequest.setValue(tokenTransferMethod.rawValue, forHTTPHeaderField: "st-auth-mode")

            if localSessionState.status == .EXISTS {
                let hadAuthorizationHeader = mutableRequest.value(forHTTPHeaderField: "Authorization") != nil
                Utils.setAuthorizationHeaderIfRequired(mutableRequest: mutableRequest)
                didAddAuthorizationHeader = !hadAuthorizationHeader && mutableRequest.value(forHTTPHeaderField: "Authorization") != nil
            }
            return localSessionState
        }

        let preRequestLocalSessionState = sessionSnapshot.value
        let requestGeneration = sessionSnapshot.generation
        let requestSequence = sessionSnapshot.sequence
        
        let apiRequest = mutableRequest.copy() as! URLRequest
        
        // We need to use a custom URLSession here because otherwise it will use this protocol, causing an infinite loop
        let customSession = URLSession(configuration: URLSessionConfiguration.default)
        customSession.dataTask(with: apiRequest, completionHandler: {
            data, response, error in
            
            if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
                let tokenUpdate = SessionStateCoordinator.applyResponse(expectedGeneration: requestGeneration, requestSequence: requestSequence) {
                    Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: httpResponse)
                }

                if case .failed = tokenUpdate {
                    self.resolveToUser(data: nil, response: nil, error: SuperTokensError.generalError(message: "Could not update session storage"))
                    return
                }

                if case .stale = tokenUpdate {
                    if httpResponse.statusCode != SuperTokens.config!.sessionExpiredStatusCode {
                        self.resolveToUser(data: data, response: response, error: error)
                        return
                    }
                }

                if case .applied(let shouldFirePayloadUpdated, let committedGeneration) = tokenUpdate {
                    if shouldFirePayloadUpdated {
                        SuperTokens.config!.eventHandler(.ACCESS_TOKEN_PAYLOAD_UPDATED)
                    }

                    if SessionStateCoordinator.isCurrent(committedGeneration) {
                        Utils.fireSessionUpdateEventsIfNecessary(
                            wasLoggedIn: preRequestLocalSessionState.status == .EXISTS,
                            status: httpResponse.statusCode,
                            frontTokenheaderFromResponse: httpResponse.value(forHTTPHeaderField: SuperTokensConstants.frontTokenHeaderKey)
                        )
                    }
                }
                
                if httpResponse.statusCode == SuperTokens.config!.sessionExpiredStatusCode {
                    /**
                    * An API may return a 401 error response even with a valid session, causing a session refresh loop in the interceptor.
                    * To prevent this infinite loop, we break out of the loop after retrying the original request a specified number of times.
                    * The maximum number of retry attempts is defined by maxRetryAttemptsForSessionRefresh config variable.
                    */
                    if self.sessionRefreshAttempts >= SuperTokens.config!.maxRetryAttemptsForSessionRefresh {
                        let errorMessage = "Error: Received 401 response from \(String(describing: apiRequest.url)). After refreshing the session and retrying the request \(SuperTokens.config!.maxRetryAttemptsForSessionRefresh ) times, we still received 401 responses. Maximum session refresh limit reached. Breaking out of the refresh loop. Please investigate your API. Consider increasing maxRetryAttemptsForSessionRefresh in the config if needed."
                        print(errorMessage)
                        self.resolveToUser(data: nil, response: nil, error: SuperTokensError.maxRetryAttemptsReachedForSessionRefresh(message: errorMessage))
                        return
                    }

                    if didAddAuthorizationHeader {
                        mutableRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                        mutableRequest.setValue(nil, forHTTPHeaderField: "authorization")
                    } else {
                        mutableRequest = self.removeAuthHeaderIfMatchesLocalToken(_mutableRequest: mutableRequest)
                    }
                    SuperTokensURLProtocol.onUnauthorisedResponse(preRequestLocalSessionState: preRequestLocalSessionState, callback: {
                        unauthResponse in
                        
                        self.sessionRefreshAttempts += 1;
                        
                        if unauthResponse.status == .RETRY {
                            self.requestForRetry = mutableRequest
                            self.makeRequest()
                        } else {                            
                            if unauthResponse.error != nil {
                                self.resolveToUser(data: nil, response: nil, error: unauthResponse.error)
                            } else {
                                self.resolveToUser(data: data, response: response, error: unauthResponse.error)
                            }
                        }
                    })
                } else {                    
                    self.resolveToUser(data: data, response: response, error: error)
                }
            } else {
                self.resolveToUser(data: data, response: response, error: error)
            }
        }).resume()
    }
    
    func resolveToUser(data: Data?, response: URLResponse?, error: Error?) {
        // This will call the appropriate callbacks and return the data back to the user
        if error != nil {
            self.client?.urlProtocol(self, didFailWithError: error!)
        }
        
        if data != nil {
            self.client?.urlProtocol(self, didLoad: data!)
        }
        
        if response != nil {
            self.client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
        }
        
        // After everything, we need to call this to indicate to URLSession that this protocol has finished its task
        self.client?.urlProtocolDidFinishLoading(self)
    }
    
    private static func statusAfterStaleResponse() -> UnauthorisedResponse.UnauthorisedStatus {
        let currentState = SessionStateCoordinator.snapshot { Utils.getLocalSessionState() }.value
        return currentState.status == .EXISTS ? .RETRY : .SESSION_EXPIRED
    }

    internal static func runRefreshApplicationCallback<T>(_ body: () -> T) -> T {
        Thread.current.threadDictionary[refreshApplicationCallbackKey] = true
        defer { Thread.current.threadDictionary.removeObject(forKey: refreshApplicationCallbackKey) }
        return body()
    }

    private static func completeRefresh(expectedEpoch: UInt64, _ response: UnauthorisedResponse) {
        refreshStateQueue.async {
            guard refreshInProgress, refreshEpoch == expectedEpoch else { return }
            let callbacks = refreshCallbacks
            refreshCallbacks.removeAll()
            refreshInProgress = false

            DispatchQueue.global().async {
                callbacks.forEach { $0(response) }
            }
        }
    }

    internal static func resetForTests() {
        var callbacks: [(UnauthorisedResponse) -> Void] = []
        refreshStateQueue.sync {
            refreshEpoch &+= 1
            callbacks = refreshCallbacks
            refreshCallbacks.removeAll()
            refreshInProgress = false
        }

        let response = UnauthorisedResponse(status: .API_ERROR, error: SuperTokensError.generalError(message: "Session refresh reset during testing"))
        callbacks.forEach { $0(response) }
    }

    static func onUnauthorisedResponse(preRequestLocalSessionState: LocalSessionState, callback: @escaping (UnauthorisedResponse) -> Void) {
        if Thread.current.threadDictionary[refreshApplicationCallbackKey] as? Bool == true {
            callback(UnauthorisedResponse(status: .SESSION_EXPIRED))
            return
        }

        refreshStateQueue.async {
            let sessionSnapshot = SessionStateCoordinator.requestSnapshot { () -> (state: LocalSessionState, request: URLRequest?) in
                let state = Utils.getLocalSessionState()
                guard state.status == .EXISTS else { return (state, nil) }

                let refreshUrl = URL(string: SuperTokens.refreshTokenUrl)!
                var request = URLRequest(url: refreshUrl)
                request.httpMethod = "POST"

                let antiCSRF = AntiCSRF.getToken(associatedAccessTokenUpdate: state.lastAccessTokenUpdate!)
                if antiCSRF != nil {
                    request.addValue(antiCSRF!, forHTTPHeaderField: SuperTokensConstants.antiCSRFHeaderKey)
                }

                request.addValue(SuperTokens.rid, forHTTPHeaderField: "rid")
                request.addValue(Version.supported_fdi.joined(separator: ","), forHTTPHeaderField: "fdi-version")
                request.setValue(SuperTokens.config!.tokenTransferMethod.rawValue, forHTTPHeaderField: "st-auth-mode")

                let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
                Utils.setAuthorizationHeaderIfRequired(mutableRequest: mutableRequest, addRefreshToken: true)
                return (state, mutableRequest.copy() as? URLRequest)
            }
            let postLockLocalSessionState = sessionSnapshot.value.state
            let refreshGeneration = sessionSnapshot.generation
            let refreshSequence = sessionSnapshot.sequence

            if postLockLocalSessionState.status == .NOT_EXISTS {
                DispatchQueue.global().async {
                    SuperTokens.config!.eventHandler(.UNAUTHORISED)
                    callback(UnauthorisedResponse(status: .SESSION_EXPIRED))
                }
                return
            }

            if postLockLocalSessionState.status != preRequestLocalSessionState.status || (postLockLocalSessionState.status == .EXISTS && preRequestLocalSessionState.status == .EXISTS && postLockLocalSessionState.lastAccessTokenUpdate! != preRequestLocalSessionState.lastAccessTokenUpdate!) {
                DispatchQueue.global().async {
                    callback(UnauthorisedResponse(status: .RETRY))
                }
                return
            }

            refreshCallbacks.append(callback)
            guard !refreshInProgress else { return }
            refreshInProgress = true
            let currentRefreshEpoch = refreshEpoch

            let initialRefreshRequest = sessionSnapshot.value.request!
            DispatchQueue.global().async {
                let refreshRequest = runRefreshApplicationCallback {
                    SuperTokens.config!.preAPIHook(.REFRESH_SESSION, initialRefreshRequest)
                }

                let customSession = URLSession(configuration: URLSessionConfiguration.default)
                let refreshTask = customSession.dataTask(with: refreshRequest, completionHandler: { _, response, error in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: .API_ERROR, error: error))
                        return
                    }

                    let isUnauthorised = httpResponse.statusCode == SuperTokens.config!.sessionExpiredStatusCode
                    let tokenUpdate = SessionStateCoordinator.applyResponse(expectedGeneration: refreshGeneration, requestSequence: refreshSequence) {
                        let result = Utils.saveTokenFromHeadersWithoutFiringEvent(httpResponse: httpResponse)
                        guard result.success else { return result }

                        if isUnauthorised && httpResponse.value(forHTTPHeaderField: SuperTokensConstants.frontTokenHeaderKey) == nil {
                            return SessionTokenUpdateResult(success: FrontToken.removeToken(), shouldFirePayloadUpdated: result.shouldFirePayloadUpdated, didMutateSession: true, clearsSession: true)
                        }

                        return result
                    }

                    switch tokenUpdate {
                    case .stale:
                        completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: statusAfterStaleResponse()))
                        return
                    case .failed:
                        completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: .API_ERROR, error: SuperTokensError.generalError(message: "Could not update session storage")))
                        return
                    case .applied(let shouldFirePayloadUpdated, let committedGeneration):
                        if shouldFirePayloadUpdated {
                            runRefreshApplicationCallback {
                                SuperTokens.config!.eventHandler(.ACCESS_TOKEN_PAYLOAD_UPDATED)
                            }
                        }

                        guard SessionStateCoordinator.isCurrent(committedGeneration) else {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: statusAfterStaleResponse()))
                            return
                        }

                        let frontTokenInHeaders = httpResponse.value(forHTTPHeaderField: SuperTokensConstants.frontTokenHeaderKey)
                        runRefreshApplicationCallback {
                            Utils.fireSessionUpdateEventsIfNecessary(
                                wasLoggedIn: preRequestLocalSessionState.status == .EXISTS,
                                status: httpResponse.statusCode,
                                frontTokenheaderFromResponse: frontTokenInHeaders == nil ? "remove" : frontTokenInHeaders!
                            )
                        }

                        guard SessionStateCoordinator.isCurrent(committedGeneration) else {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: statusAfterStaleResponse()))
                            return
                        }

                        if httpResponse.statusCode >= 300 {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: .API_ERROR, error: SuperTokensError.apiError(message: "Refresh API returned with status code: \(httpResponse.statusCode)")))
                            return
                        }

                        runRefreshApplicationCallback {
                            SuperTokens.config!.postAPIHook(.REFRESH_SESSION, refreshRequest, response)
                        }

                        guard SessionStateCoordinator.isCurrent(committedGeneration) else {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: statusAfterStaleResponse()))
                            return
                        }

                        if Utils.getLocalSessionState().status == .NOT_EXISTS {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: .SESSION_EXPIRED))
                            return
                        }

                        runRefreshApplicationCallback {
                            SuperTokens.config!.eventHandler(.REFRESH_SESSION)
                        }
                        if SessionStateCoordinator.isCurrent(committedGeneration) {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: .RETRY))
                        } else {
                            completeRefresh(expectedEpoch: currentRefreshEpoch, UnauthorisedResponse(status: statusAfterStaleResponse()))
                        }
                    }
                })
                refreshTask.resume()
            }
        }
    }
    
    public override func stopLoading() {
        // Do nothing, this is required to be implemented
    }
}
