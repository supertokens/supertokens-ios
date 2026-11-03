//
//  Utils.swift
//  SuperTokensSession
//
//  Created by Nemi Shah on 30/09/22.
//

import Foundation

internal enum TokenType {
    case access, refresh
}

extension TokenType {
    internal func getStorageName() -> String {
        if self == .access {
            return SuperTokensConstants.ACCESS_TOKEN_NAME
        }
        
        return SuperTokensConstants.REFRESH_TOKEN_NAME
    }
}

internal enum LocalSessionStateStatus {
    case NOT_EXISTS, EXISTS
}

internal class LocalSessionState {
    let status: LocalSessionStateStatus
    let lastAccessTokenUpdate: String?
    
    init(status: LocalSessionStateStatus, lastAccessTokenUpdate: String?) {
        self.status = status
        self.lastAccessTokenUpdate = lastAccessTokenUpdate
    }
}

internal struct SessionTokenUpdateResult {
    let success: Bool
    let shouldFirePayloadUpdated: Bool
    let didMutateSession: Bool
    let clearsSession: Bool
    let startsNewSession: Bool

    init(success: Bool, shouldFirePayloadUpdated: Bool, didMutateSession: Bool, clearsSession: Bool, startsNewSession: Bool = false) {
        self.success = success
        self.shouldFirePayloadUpdated = shouldFirePayloadUpdated
        self.didMutateSession = didMutateSession
        self.clearsSession = clearsSession
        self.startsNewSession = startsNewSession
    }
}

internal enum SessionResponseUpdateResult {
    case staleGeneration
    case outOfOrder
    case failed
    case applied(shouldFirePayloadUpdated: Bool, generation: UInt64)
}

internal class SessionStateCoordinator {
    // Storage helpers nest synchronously inside a session transaction, on this thread.
    private static let lock = NSRecursiveLock()
    private static var mutationDepth = 0
    private static var listeners: [UUID: (SessionSnapshot) -> Void] = [:]
    private static var lifecycleListeners: [UUID: (SessionLifecycleEvent) -> Void] = [:]
    internal static var beforeLifecycleDeliveryForTests: (() -> Void)?
    private static var generation: UInt64 = 0
    private static var nextRequestSequence: UInt64 = 0
    private static var lastAppliedRequestSequence: UInt64 = 0

    internal static func snapshot<T>(_ body: () -> T) -> (value: T, generation: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        return (body(), generation)
    }

    internal static func requestSnapshot<T>(_ body: () -> T) -> (value: T, generation: UInt64, sequence: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        nextRequestSequence &+= 1
        return (body(), generation, nextRequestSequence)
    }

    internal static func sessionSnapshot() -> SessionSnapshot {
        return snapshot { readSessionSnapshot() }.value
    }

    private static func readSessionSnapshot() -> SessionSnapshot {
        SessionSnapshot(generation: generation,
                        accessToken: SDKStorage.get(SDKStorage.genericKey(SuperTokensConstants.ACCESS_TOKEN_NAME)),
                        refreshToken: SDKStorage.get(SDKStorage.genericKey(SuperTokensConstants.REFRESH_TOKEN_NAME)),
                        frontToken: SDKStorage.get(SDKStorage.frontTokenKey),
                        antiCSRFToken: SDKStorage.get(SDKStorage.antiCSRFKey),
                        lastAccessTokenUpdate: SDKStorage.get(SDKStorage.genericKey(SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE)))
    }

    internal static func addListener(_ listener: @escaping (SessionSnapshot) -> Void) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        listeners[id] = listener
        return id
    }

    internal static func removeListener(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        listeners.removeValue(forKey: id)
    }

    internal static func addLifecycleListener(_ listener: @escaping (SessionLifecycleEvent) -> Void) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        lifecycleListeners[id] = listener
        return id
    }

    internal static func removeLifecycleListener(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        lifecycleListeners.removeValue(forKey: id)
    }

    internal static func emitLifecycle(_ type: EventType, expectedGeneration: UInt64) {
        lock.lock()
        guard generation == expectedGeneration else { lock.unlock(); return }
        let callbacks = Array(lifecycleListeners.values)
        let legacy = SuperTokens.config?.eventHandler
        let hook = beforeLifecycleDeliveryForTests
        let event = SessionLifecycleEvent(type: type, generation: generation)
        lock.unlock()

        hook?()
        // Both forms belong to this admitted transition, even if either callback
        // is delayed or reenters session APIs. Later listeners are rechecked.
        legacy?(type)
        for (index, callback) in callbacks.enumerated() {
            if index > 0 && !isCurrent(event.generation) { break }
            callback(event)
        }
    }

    internal static func legacyMutation(_ body: () -> Bool) -> Bool {
        lock.lock()
        if mutationDepth > 0 {
            defer { lock.unlock() }
            return body()
        }
        // Keep the check and outer transaction atomic; release before callbacks.
        mutationDepth += 1
        generation &+= 1
        lastAppliedRequestSequence = 0
        let success = body()
        mutationDepth -= 1
        let callbacks = Array(listeners.values)
        let state = callbacks.isEmpty ? nil : readSessionSnapshot()
        lock.unlock()
        if let state { callbacks.forEach { $0(state) } }
        return success
    }

    internal static func performAuthoritativeMutation(expectedGeneration: UInt64? = nil, _ body: () -> SessionTokenUpdateResult) -> SessionTokenUpdateResult {
        lock.lock()
        if let expectedGeneration, generation != expectedGeneration {
            lock.unlock()
            return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: false, clearsSession: false)
        }
        generation &+= 1
        lastAppliedRequestSequence = 0
        mutationDepth += 1
        let result = body()
        mutationDepth -= 1
        let callbacks = Array(listeners.values)
        let committedGeneration = generation
        let state = callbacks.isEmpty ? nil : readSessionSnapshot()
        lock.unlock()
        if let state { callbacks.forEach { $0(state) } }
        if result.success && result.shouldFirePayloadUpdated {
            emitLifecycle(.ACCESS_TOKEN_PAYLOAD_UPDATED, expectedGeneration: committedGeneration)
        }
        return result
    }

    internal static func applyResponse(expectedGeneration: UInt64, requestSequence: UInt64, allowOutOfOrder: (() -> Bool)? = nil, _ body: () -> SessionTokenUpdateResult) -> SessionResponseUpdateResult {
        lock.lock()

        guard generation == expectedGeneration else {
            lock.unlock()
            return .staleGeneration
        }

        guard requestSequence >= lastAppliedRequestSequence || allowOutOfOrder?() == true else {
            lock.unlock()
            return .outOfOrder
        }

        mutationDepth += 1
        let result = body()
        mutationDepth -= 1
        guard result.success else {
            generation &+= 1
            lastAppliedRequestSequence = 0
            let callbacks = Array(listeners.values)
            let state = callbacks.isEmpty ? nil : readSessionSnapshot()
            lock.unlock()
            if let state { callbacks.forEach { $0(state) } }
            return .failed
        }

        if result.didMutateSession {
            if result.clearsSession || result.startsNewSession {
                generation &+= 1
                lastAppliedRequestSequence = 0
            } else {
                lastAppliedRequestSequence = requestSequence
            }
        }

        let callbacks = result.didMutateSession ? Array(listeners.values) : []
        let committedGeneration = generation
        let state = callbacks.isEmpty ? nil : readSessionSnapshot()
        lock.unlock()
        if let state { callbacks.forEach { $0(state) } }
        return .applied(shouldFirePayloadUpdated: result.shouldFirePayloadUpdated, generation: committedGeneration)
    }

    internal static func isCurrent(_ expectedGeneration: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == expectedGeneration
    }

    internal static func resetForTests() {
        lock.lock()
        generation &+= 1
        lastAppliedRequestSequence = 0
        listeners.removeAll()
        lifecycleListeners.removeAll()
        beforeLifecycleDeliveryForTests = nil
        lock.unlock()
    }
}

public enum SuperTokensTokenTransferMethod: String {
    case cookie, header
}

class NormalisedInputType {
    var apiDomain: String
    var apiBasePath: String
    var sessionExpiredStatusCode: Int
    /**
     * This specifies the maximum number of times the interceptor will attempt to refresh
     * the session  when a 401 Unauthorized response is received. If the number of retries
     * exceeds this limit, no further attempts will be made to refresh the session, and
     * and an error will be thrown.
     */
    var maxRetryAttemptsForSessionRefresh: Int
    var sessionTokenBackendDomain: String?
    var eventHandler: (EventType) -> Void
    var preAPIHook: (APIAction, URLRequest) -> URLRequest
    var postAPIHook: (APIAction, URLRequest, URLResponse?) -> Void
    var userDefaultsSuiteName: String?
    var keychainAccessGroup: String?
    var tokenTransferMethod: SuperTokensTokenTransferMethod
    
    init(apiDomain: String, apiBasePath: String, sessionExpiredStatusCode: Int, maxRetryAttemptsForSessionRefresh: Int, sessionTokenBackendDomain: String?, tokenTransferMethod: SuperTokensTokenTransferMethod, eventHandler: @escaping (EventType) -> Void, preAPIHook: @escaping (APIAction, URLRequest) -> URLRequest, postAPIHook: @escaping (APIAction, URLRequest, URLResponse?) -> Void, userDefaultsSuiteName: String?, keychainAccessGroup: String?) {
        self.apiDomain = apiDomain
        self.apiBasePath = apiBasePath
        self.sessionExpiredStatusCode = sessionExpiredStatusCode
        self.maxRetryAttemptsForSessionRefresh = maxRetryAttemptsForSessionRefresh
        self.sessionTokenBackendDomain = sessionTokenBackendDomain
        self.eventHandler = eventHandler
        self.preAPIHook = preAPIHook
        self.postAPIHook = postAPIHook
        self.userDefaultsSuiteName = userDefaultsSuiteName
        self.keychainAccessGroup = keychainAccessGroup
        self.tokenTransferMethod = tokenTransferMethod
    }
    
    internal static func sessionScopeHelper(sessionScope: String) throws -> String {
        var trimmedSessionScope = sessionScope.trim().lowercased()

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

            return host
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
    
    internal static func normaliseInputType(apiDomain: String, apiBasePath: String?, sessionExpiredStatusCode: Int?, maxRetryAttemptsForSessionRefresh: Int? = nil, sessionTokenBackendDomain: String?, tokenTransferMethod: SuperTokensTokenTransferMethod?, eventHandler: ((EventType) -> Void)?, preAPIHook: ((APIAction, URLRequest) -> URLRequest)?, postAPIHook: ((APIAction, URLRequest, URLResponse?) -> Void)?, userDefaultsSuiteName: String?, keychainAccessGroup: String?) throws -> NormalisedInputType {
        let _apiDomain = try NormalisedURLDomain(url: apiDomain)
        var _apiBasePath = try NormalisedURLPath(input: "/auth")
        
        if apiBasePath != nil {
            _apiBasePath = try NormalisedURLPath(input: apiBasePath!)
        }
        
        var _sessionExpiredStatusCode: Int = 401
        if sessionExpiredStatusCode != nil {
            _sessionExpiredStatusCode = sessionExpiredStatusCode!
        }
        
        var _maxRetryAttemptsForSessionRefresh: Int = 10
        if maxRetryAttemptsForSessionRefresh != nil {
            _maxRetryAttemptsForSessionRefresh = maxRetryAttemptsForSessionRefresh!
        }
        
        var _sessionTokenBackendDomain: String? = nil
        if sessionTokenBackendDomain != nil {
            _sessionTokenBackendDomain = try normaliseSessionScopeOrThrowError(sessionScope: sessionTokenBackendDomain!)
        }
        
        var _eventHandler: (EventType) -> Void = { _ in }
        if eventHandler != nil {
            _eventHandler = eventHandler!
        }
        
        var _preAPIHook: (APIAction, URLRequest) -> URLRequest = {
            _, request in
            
            return request
        }
        if preAPIHook != nil {
            _preAPIHook = preAPIHook!
        }
        
        var _postApiHook: (APIAction, URLRequest, URLResponse?) -> Void = {
            _, _, _ in
        }
        if postAPIHook != nil {
            _postApiHook = postAPIHook!
        }
        
        var _tokenTransferMethod: SuperTokensTokenTransferMethod = .header
        
        if tokenTransferMethod != nil {
            _tokenTransferMethod = tokenTransferMethod!
        }
        
        
        return NormalisedInputType(apiDomain: _apiDomain.getAsStringDangerous(), apiBasePath: _apiBasePath.getAsStringDangerous(), sessionExpiredStatusCode: _sessionExpiredStatusCode, maxRetryAttemptsForSessionRefresh: _maxRetryAttemptsForSessionRefresh, sessionTokenBackendDomain: _sessionTokenBackendDomain, tokenTransferMethod: _tokenTransferMethod, eventHandler: _eventHandler, preAPIHook: _preAPIHook, postAPIHook: _postApiHook, userDefaultsSuiteName: userDefaultsSuiteName, keychainAccessGroup: keychainAccessGroup)
    }
}

internal class Utils {
    internal static func shouldDoInterception(toCheckURL: String, apiDomain: String, cookieDomain: String?) throws -> Bool {
        let normalizedToCheckURL = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: toCheckURL)
        guard let urlObj = URL(string: normalizedToCheckURL), let hostname = urlObj.host else {
            throw SDKFailableError.failableError
        }

        let domain = hostname
        var apiDomainAndInputDomainMatch = false
        if !apiDomain.isEmpty {
            let normalizedApiDomain = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: apiDomain)
            guard let apiUrlObj = URL(string: normalizedApiDomain), let apiHostName = apiUrlObj.host else {
                throw SDKFailableError.failableError
            }
            apiDomainAndInputDomainMatch = domain == apiHostName
        }

        if cookieDomain == nil || apiDomainAndInputDomainMatch {
            // even if cookieDomain isn't undefined, if there is an exact match
            // of api domain, ignoring the port, we return true
            return apiDomainAndInputDomainMatch
        } else {
            let normalisedSessionDomain = try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: cookieDomain!)
            // Using the matchesDomainOrSubdomain function to determine match
            return matchesDomainOrSubdomain(domain: domain, str: normalisedSessionDomain)
        }
    }

    private static func matchesDomainOrSubdomain(domain: String, str: String) -> Bool {
        let parts = domain.split(separator: ".").map(String.init)

        for i in 0..<parts.count {
            let subdomainCandidate = parts[i...].joined(separator: ".")
            if subdomainCandidate == str || ".\(subdomainCandidate)" == str {
                return true
            }
        }

        return false
    }
    
    internal static func isIpAddress(input: String) -> Bool {
        let regex: String = "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        
        return input.matches(regex: regex)
    }
    
    internal static func getUserDefaults() -> UserDefaults {
        if let _suiteName: String = SuperTokens.config?.userDefaultsSuiteName {
            if let _userDefaultsWithSuiteName: UserDefaults = UserDefaults(suiteName: _suiteName) {
                return _userDefaultsWithSuiteName
            } else {
                print("SuperTokens: Could not initialise user defaults with suite name '\(_suiteName)', using default")
            }
        }
        
        return UserDefaults.standard
    }
    
    internal static func storeInStorage(name: String, value: String) -> Bool {
        return SDKStorage.set(SDKStorage.genericKey(name), value: value)
    }
    
    internal static func saveLastAccessTokenUpdate() -> Bool {
        let now = "\(Date().timeIntervalSince1970 * 1000)";
        
        if !storeInStorage(name: SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE, value: now) {
            return false
        }
        
        return storeInStorage(name: "sIRTFrontend", value: "")
    }
    
    internal static func getFromStorage(name: String) -> String? {
        let itemInStorage = SDKStorage.get(SDKStorage.genericKey(name))
        
        if itemInStorage == nil {
            return nil
        }
        
        return itemInStorage
    }
    
    internal static func getLocalSessionState() -> LocalSessionState {
        let lastAccessTokenUpdate = getFromStorage(name: SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE)
        let frontTokenExists = FrontToken.doesTokenExist()
        
        if frontTokenExists && lastAccessTokenUpdate != nil {
            return LocalSessionState(status: .EXISTS, lastAccessTokenUpdate: lastAccessTokenUpdate)
        } else {
            return LocalSessionState(status: .NOT_EXISTS, lastAccessTokenUpdate: nil)
        }
    }
    
    @discardableResult
    internal static func setToken(tokenType: TokenType, value: String) -> Bool {
        let name = tokenType.getStorageName()
        
        return storeInStorage(name: name, value: value)
    }
    
    @discardableResult
    internal static func saveTokenFromHeaders(httpResponse: HTTPURLResponse) -> Bool {
        return SessionStateCoordinator.performAuthoritativeMutation {
            saveTokenFromHeadersWithoutFiringEvent(httpResponse: httpResponse)
        }.success
    }

    internal static func saveTokenFromHeadersWithoutFiringEvent(httpResponse: HTTPURLResponse, isRefreshResponse: Bool = false) -> SessionTokenUpdateResult {
        guard var headerFields: [String: String] = httpResponse.allHeaderFields as? [String: String] else {
            return SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: false, didMutateSession: false, clearsSession: false)
        }

        headerFields.lowerCaseKeys()

        let startsNewSession = responseStartsNewSession(headerFields: headerFields, isRefreshResponse: isRefreshResponse)

        if let frontToken = headerFields[SuperTokensConstants.frontTokenHeaderKey],
           frontToken != "remove",
           !FrontToken.isWellFormed(frontToken) {
            return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: false, clearsSession: false)
        }

        if headerFields[SuperTokensConstants.frontTokenHeaderKey] == "remove" {
            guard FrontToken.removeToken() else {
                SDKStorage.clearSessionStorage()
                return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: true)
            }

            return SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: true)
        }

        var shouldFirePayloadUpdated = false
        var didMutateSession = false
        
        if let refreshToken: String = headerFields[SuperTokensConstants.refreshTokenHeaderKey] {
            didMutateSession = true
            guard Utils.setToken(tokenType: .refresh, value: refreshToken) else {
                SDKStorage.clearSessionStorage()
                return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: false)
            }
        }
        
        if let accessToken: String = headerFields[SuperTokensConstants.accessTokenHeaderKey] {
            didMutateSession = true
            guard Utils.setToken(tokenType: .access, value: accessToken) else {
                SDKStorage.clearSessionStorage()
                return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: false)
            }
        }
        
        if let frontToken: String = headerFields[SuperTokensConstants.frontTokenHeaderKey] {
            didMutateSession = true
            let result = FrontToken.setItemWithoutFiringEvent(frontToken: frontToken)
            guard result.success else {
                SDKStorage.clearSessionStorage()
                return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: false)
            }
            shouldFirePayloadUpdated = result.shouldFirePayloadUpdated
        }
        
        if let antiCSRF: String = headerFields[SuperTokensConstants.antiCSRFHeaderKey] {
            didMutateSession = true
            let localSessionState = Utils.getLocalSessionState()
            
            guard AntiCSRF.setToken(antiCSRFToken: antiCSRF, associatedAccessTokenUpdate: localSessionState.lastAccessTokenUpdate) else {
                SDKStorage.clearSessionStorage()
                return SessionTokenUpdateResult(success: false, shouldFirePayloadUpdated: false, didMutateSession: true, clearsSession: false)
            }
        }

        return SessionTokenUpdateResult(success: true, shouldFirePayloadUpdated: shouldFirePayloadUpdated, didMutateSession: didMutateSession, clearsSession: false, startsNewSession: startsNewSession)
    }

    internal static func responseStartsNewSession(httpResponse: HTTPURLResponse, isRefreshResponse: Bool = false) -> Bool {
        guard var headerFields = httpResponse.allHeaderFields as? [String: String] else { return false }
        headerFields.lowerCaseKeys()
        return responseStartsNewSession(headerFields: headerFields, isRefreshResponse: isRefreshResponse)
    }

    private static func responseStartsNewSession(headerFields: [String: String], isRefreshResponse: Bool) -> Bool {
        guard let incomingFrontToken = headerFields[SuperTokensConstants.frontTokenHeaderKey],
              incomingFrontToken != "remove",
              let incomingUserId = FrontToken.parseFrontToken(frontTokenDecoded: incomingFrontToken)?["uid"] as? String else {
            return false
        }

        if !isRefreshResponse && headerFields[SuperTokensConstants.refreshTokenHeaderKey] != nil {
            if let current = sessionHandle(getTokenForHeaderAuth(tokenType: .access)),
               let incoming = sessionHandle(headerFields[SuperTokensConstants.accessTokenHeaderKey]) {
                return current != incoming
            }
            return true
        }

        guard let currentUserId = FrontToken.getToken()?["uid"] as? String else {
            return true
        }

        return currentUserId != incomingUserId
    }

    private static func sessionHandle(_ token: String?) -> String? {
        guard let token = token else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let handle = claims["sessionHandle"] as? String, !handle.isEmpty else { return nil }
        return handle
    }
    
    internal static func getTokenForHeaderAuth(tokenType: TokenType) -> String? {
        let name = tokenType.getStorageName()
        
        return getFromStorage(name: name)
    }
    
    internal static func setAuthorizationHeaderIfRequired(mutableRequest: NSMutableURLRequest, addRefreshToken: Bool = false) {
        // We set the Authorization header even if the tokenTransferMethod preference set in the config is cookies
        // since the active session may be using cookies. By default, we want to allow users to continue these sessions.
        // The new session preference should be applied at the start of the next session, if the backend allows it.
        
        let accessToken = Utils.getTokenForHeaderAuth(tokenType: .access)
        let refreshToken = Utils.getTokenForHeaderAuth(tokenType: .refresh)
        
        // We don't always need the refresh token because that's only required by the refresh call
        // Still, we only add the Authorization header if both are present, because we are planning to add an option to expose the
        // access token to the frontend while using cookie based auth - so that users can get the access token to use
        if accessToken != nil && refreshToken != nil {
            if mutableRequest.value(forHTTPHeaderField: "Authorization") != nil {
                // no-op
            } else {
                let tokenToAdd = addRefreshToken ? refreshToken! : accessToken!
                mutableRequest.setValue("Bearer \(tokenToAdd)", forHTTPHeaderField: "Authorization")
            }
        }
    }
    
    internal static func fireSessionUpdateEventsIfNecessary(
        wasLoggedIn: Bool,
        status: Int,
        frontTokenheaderFromResponse: String?,
        generation: UInt64
    ) {
        // In case we've received a 401 that didn't clear the session (e.g.: we've sent no session token, or we should try refreshing)
        // then onUnauthorised will handle firing the UNAUTHORISED event if necessary
        // In some rare cases (where we receive a 401 that also clears the session) this will fire the event twice.
        // This may be considered a bug, but it is the existing behaviour before the rework
        if frontTokenheaderFromResponse == nil {
            return
        }
        
        // if the current endpoint clears the session it'll set the front-token to remove
        // any other update means it's created or updated.
        let frontTokenExistsAfter = frontTokenheaderFromResponse != "remove"
        
        if wasLoggedIn {
            // we check for wasLoggedIn cause we don't want to fire an event
            // unnecessarily on first app load or if the user tried
            // to query an API that returned 401 while the user was not logged in...
            if !frontTokenExistsAfter {
                if status == SuperTokens.config!.sessionExpiredStatusCode {
                    SessionStateCoordinator.emitLifecycle(.UNAUTHORISED, expectedGeneration: generation)
                } else {
                    SessionStateCoordinator.emitLifecycle(.SIGN_OUT, expectedGeneration: generation)
                }
            }
        } else if frontTokenExistsAfter {
            SessionStateCoordinator.emitLifecycle(.SESSION_CREATED, expectedGeneration: generation)
        }
    }
}

internal struct SignOutResponse: Codable {
    var status: String
    var message: String?
}
