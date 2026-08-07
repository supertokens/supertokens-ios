//
//  FrontToken.swift
//  SuperTokensSession
//
//  Created by Nemi Shah on 30/09/22.
//

import Foundation

internal struct FrontTokenUpdateResult {
    let success: Bool
    let shouldFirePayloadUpdated: Bool
}

internal class FrontToken {
    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    private struct Claims: Decodable {
        private enum CodingKeys: String, CodingKey {
            case uid, ate, up
        }

        let uid: String
        let ate: Int64

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            uid = try container.decode(String.self, forKey: .uid)
            ate = try container.decode(Int64.self, forKey: .ate)
            _ = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .up)
        }
    }

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
    
    internal static func parseFrontToken(frontTokenDecoded: String) -> [String: Any]? {
        guard let decodedData = Data(base64Encoded: frontTokenDecoded),
              let claims = try? JSONDecoder().decode(Claims.self, from: decodedData),
              var json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
              json["up"] is [String: Any],
              let expiry = Int(exactly: claims.ate) else {
            return nil
        }

        json["uid"] = claims.uid
        json["ate"] = expiry
        return json
    }

    internal static func isWellFormed(_ frontToken: String) -> Bool {
        return parseFrontToken(frontTokenDecoded: frontToken) != nil
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
    
    private static func payloadString(fromFrontToken frontToken: String) -> String? {
        guard let json = parseFrontToken(frontTokenDecoded: frontToken),
              let payload = json["up"] as? [String: Any],
              let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            return nil
        }

        return payloadString
    }

    private static func setFrontTokenWithoutFiringEvent(frontToken: String) -> FrontTokenUpdateResult {
        guard isWellFormed(frontToken) else {
            return FrontTokenUpdateResult(success: false, shouldFirePayloadUpdated: false)
        }

        let oldToken = getFrontTokenFromStorage()
        var shouldFirePayloadUpdated = false

        if let oldToken = oldToken {
            let oldPayloadString = payloadString(fromFrontToken: oldToken)
            let newPayloadString = payloadString(fromFrontToken: frontToken)

            // If either token cannot be parsed (e.g. a corrupt value left in
            // storage), do not crash — treat the payload as changed so observers
            // re-read, which is the safe superset of the equality check below.
            if oldPayloadString == nil || oldPayloadString != newPayloadString {
                shouldFirePayloadUpdated = true
            }
        }

        guard setFrontTokenToStorage(frontToken: frontToken) else {
            return FrontTokenUpdateResult(success: false, shouldFirePayloadUpdated: false)
        }

        return FrontTokenUpdateResult(success: true, shouldFirePayloadUpdated: shouldFirePayloadUpdated)
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
    static func setItemWithoutFiringEvent(frontToken: String) -> FrontTokenUpdateResult {
        if frontToken == "remove" {
            return FrontTokenUpdateResult(success: FrontToken.removeToken(), shouldFirePayloadUpdated: false)
        }

        guard isWellFormed(frontToken) else {
            return FrontTokenUpdateResult(success: false, shouldFirePayloadUpdated: false)
        }

        // We update the refresh attempt info here as well, since this means that we've updated the session in some way
        // This could be both by a refresh call or if the access token was updated in a custom endpoint
        // By saving every time the access token has been updated, we cause an early retry if
        // another request has failed with a 401 with the previous access token and the token still exists.
        // Check the start and end of onUnauthorisedResponse
        // As a side-effect we reload the anti-csrf token to check if it was changed by another tab.
        guard Utils.saveLastAccessTokenUpdate() else {
            SDKStorage.clearSessionStorage()
            return FrontTokenUpdateResult(success: false, shouldFirePayloadUpdated: false)
        }

        let result = FrontToken.setFrontTokenWithoutFiringEvent(frontToken: frontToken)
        guard result.success else {
            tokenInMemory = nil
            SDKStorage.clearSessionStorage()
            return result
        }

        return result
    }

    @discardableResult
    static func setItem(frontToken: String) -> Bool {
        let result = setItemWithoutFiringEvent(frontToken: frontToken)

        if result.success && result.shouldFirePayloadUpdated {
            SuperTokens.config!.eventHandler(.ACCESS_TOKEN_PAYLOAD_UPDATED)
        }

        return result.success
    }
    
    static func doesTokenExist() -> Bool {
        guard let frontToken = FrontToken.getFrontTokenFromStorage() else { return false }
        return isWellFormed(frontToken)
    }
}
