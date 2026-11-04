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

    // Retained for internal compatibility; no independent mutable token cache.
    static var tokenInMemory: String? { SDKStorage.get(userDefaultsKey) }
    static var userDefaultsKey: String = SDKStorage.frontTokenKey
    
    private static func getFrontTokenFromStorage() -> String? {
        return SDKStorage.get(userDefaultsKey)
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
        return SessionStateCoordinator.snapshot {
            guard let token = getFrontToken() else { return nil }
            return parseFrontToken(frontTokenDecoded: token)
        }.value
    }
    
    static func getToken() -> [String: Any]? {
        return getTokenInfo()
    }
    
    private static func setFrontTokenToStorage(frontToken: String?) -> Bool {
        let didStore = SDKStorage.set(userDefaultsKey, value: frontToken ?? "")
        if !didStore {
            return false
        }

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
    
    static func clearInMemoryCache() {
        // Storage is the single source of truth; there is no cache to invalidate.
    }
    
    @discardableResult
    static func removeToken() -> Bool {
        return SDKStorage.clearSessionStorage()
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
            SDKStorage.clearSessionStorage()
            return result
        }

        return result
    }

    @discardableResult
    static func setItem(frontToken: String) -> Bool {
        return SessionStateCoordinator.performAuthoritativeMutation {
            let result = setItemWithoutFiringEvent(frontToken: frontToken)
            return SessionTokenUpdateResult(success: result.success, shouldFirePayloadUpdated: result.shouldFirePayloadUpdated,
                                            didMutateSession: true, clearsSession: frontToken == "remove")
        }.success
    }
    
    static func doesTokenExist() -> Bool {
        guard let frontToken = FrontToken.getFrontTokenFromStorage() else { return false }
        return isWellFormed(frontToken)
    }
}
