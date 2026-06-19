//
//  FrontToken.swift
//  SuperTokensSession
//
//  Created by Nemi Shah on 30/09/22.
//

import Foundation

internal class FrontToken {
    static var tokenInMemory: String? = nil
    static var userDefaultsKey: String = SDKStorage.frontTokenKey
    private static let readWriteDispatchQueue = DispatchQueue(label: "io.supertokens.fronttoken.concurrent", attributes: .concurrent)
    private static var tokenInfoSemaphore = DispatchSemaphore(value: 0)
    
    private static func getFrontTokenFromStorage() -> String? {
        if tokenInMemory == nil {
            tokenInMemory = SDKStorage.get(userDefaultsKey)
        }
        
        return tokenInMemory
    }
    
    private static func getFrontToken() -> String? {
        if Utils.getLocalSessionState().status == .NOT_EXISTS {
            return nil
        }
        
        return getFrontTokenFromStorage()
    }
    
    private static func parseFrontToken(frontTokenDecoded: String) -> [String: Any] {
        // In the event that the access token is not a valid base64 encoded json string, this will throw a runtime error
        let base64decodedData: Data = Data(base64Encoded: frontTokenDecoded)!
        let decodedString: String = String(data: base64decodedData, encoding: .utf8)!
        
        return try! JSONSerialization.jsonObject(with: decodedString.data(using: .utf8)!) as! [String: Any]
    }
    
    private static func getTokenInfo() -> [String: Any]? {
        var finalReturnValue: [String: Any]? = nil
        let executionSemaphore = DispatchSemaphore(value: 0)
        
        readWriteDispatchQueue.async {
            while (true) {
                let frontToken: String? = getFrontToken()
                
                if frontToken == nil {
                    let localSessionState = Utils.getLocalSessionState()
                    if localSessionState.status == .EXISTS {
                        tokenInfoSemaphore.wait()
                    } else {
                        finalReturnValue = nil
                        executionSemaphore.signal()
                        break
                    }
                } else {
                    finalReturnValue = parseFrontToken(frontTokenDecoded: frontToken!)
                    executionSemaphore.signal()
                    break
                }
            }
        }
        
        executionSemaphore.wait()
        return finalReturnValue
    }
    
    static func getToken() -> [String: Any]? {
        return getTokenInfo()
    }
    
    private static func setFrontTokenToStorage(frontToken: String?) -> Bool {
        let didStore = SDKStorage.set(userDefaultsKey, value: frontToken ?? "")
        if !didStore {
            return false
        }

        tokenInMemory = frontToken
        return true
    }
    
    private static func setFrontToken(frontToken: String?) -> Bool {
        let oldToken = getFrontTokenFromStorage()
        var shouldFirePayloadUpdated = false
        
        if oldToken != nil && frontToken != nil {
            let oldTokenPayload: [String: Any] = parseFrontToken(frontTokenDecoded: oldToken!)["up"] as! [String : Any]
            let newPayload: [String: Any] = parseFrontToken(frontTokenDecoded: frontToken!)["up"] as! [String : Any]
            
            let oldPayloadString = String(data: try! JSONSerialization.data(withJSONObject: oldTokenPayload), encoding: .utf8)!
            let newPayloadString = String(data: try! JSONSerialization.data(withJSONObject: newPayload), encoding: .utf8)!
            
            if oldPayloadString != newPayloadString {
                shouldFirePayloadUpdated = true
            }
        }
        
        guard setFrontTokenToStorage(frontToken: frontToken) else {
            return false
        }

        if shouldFirePayloadUpdated {
            SuperTokens.config!.eventHandler(.ACCESS_TOKEN_PAYLOAD_UPDATED)
        }

        return true
    }
    
    private static func removeTokenFromStorage() -> Bool {
        let didRemove = SDKStorage.remove(userDefaultsKey)
        if didRemove {
            tokenInMemory = nil
        }

        return didRemove
    }
    
    static func clearInMemoryCache() {
        tokenInMemory = nil
    }
    
    @discardableResult
    static func removeToken() -> Bool {
        let antiCSRFRemoved = AntiCSRF.removeToken()
        let executionSemaphore = DispatchSemaphore(value: 0)
        var didRemove = false
        
        readWriteDispatchQueue.async(flags: .barrier) {
            let frontTokenRemoved = removeTokenFromStorage()
            let accessTokenRemoved = Utils.setToken(tokenType: .access, value: "")
            let refreshTokenRemoved = Utils.setToken(tokenType: .refresh, value: "")
            let lastAccessTokenUpdateRemoved = SDKStorage.remove(SDKStorage.genericKey(SuperTokensConstants.LAST_ACCESS_TOKEN_UPDATE))
            let refreshAttemptInfoRemoved = SDKStorage.remove(SDKStorage.genericKey("sIRTFrontend"))
            didRemove = antiCSRFRemoved && frontTokenRemoved && accessTokenRemoved && refreshTokenRemoved && lastAccessTokenUpdateRemoved && refreshAttemptInfoRemoved
            tokenInfoSemaphore.signal()
            executionSemaphore.signal()
        }
        
        executionSemaphore.wait()
        return didRemove
    }
    
    @discardableResult
    static func setItem(frontToken: String) -> Bool {
        // We update the refresh attempt info here as well, since this means that we've updated the session in some way
        // This could be both by a refresh call or if the access token was updated in a custom endpoint
        // By saving every time the access token has been updated, we cause an early retry if
        // another request has failed with a 401 with the previous access token and the token still exists.
        // Check the start and end of onUnauthorisedResponse
        // As a side-effect we reload the anti-csrf token to check if it was changed by another tab.
        guard Utils.saveLastAccessTokenUpdate() else {
            SDKStorage.clearSessionStorage()
            return false
        }
        
        if frontToken == "remove" {
            return FrontToken.removeToken()
        }
        
        guard FrontToken.setFrontToken(frontToken: frontToken) else {
            tokenInMemory = nil
            SDKStorage.clearSessionStorage()
            return false
        }

        return true
    }
    
    static func doesTokenExist() -> Bool {
        let frontToken = FrontToken.getFrontTokenFromStorage()
        return frontToken != nil
    }
}
