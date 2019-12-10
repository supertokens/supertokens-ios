//
//  IdRefreshToken.swift
//  session
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
}

// TODO: verify about locking
internal class IdRefreshToken {
    private static var idRefreshInMemory: String? = nil
    private static var idRefreshUserDefaultsKey = "supertokens-ios-idrefreshtoken-key"
    
    internal static func getToken() -> String? {
        if ( IdRefreshToken.idRefreshInMemory == nil ) {
            idRefreshInMemory = IdRefreshToken.getUserDefaults().string(forKey: IdRefreshToken.idRefreshUserDefaultsKey)
        }
        if (IdRefreshToken.idRefreshInMemory != nil) {
            let splitted = IdRefreshToken.idRefreshInMemory!.components(separatedBy: ";");
            let expiry = Int64(splitted[1])!;
            let currentTime = Date().millisecondsSince1970
            if expiry < currentTime {
                IdRefreshToken.removeToken()
            }
        }
        return IdRefreshToken.idRefreshInMemory
    }
    
    internal static func setToken(newIdRefreshToken: String) {
        if (newIdRefreshToken == "remove") {
            IdRefreshToken.removeToken()
            return;
        }
        let splitted = newIdRefreshToken.components(separatedBy: ";");
        let expiry = Int64(splitted[1])!;
        let currentTime = Date().millisecondsSince1970
        if expiry < currentTime {
            IdRefreshToken.removeToken()
        } else {
            let userDefaults = IdRefreshToken.getUserDefaults()
            userDefaults.set(newIdRefreshToken, forKey: IdRefreshToken.idRefreshUserDefaultsKey)
            userDefaults.synchronize()
            IdRefreshToken.idRefreshInMemory = newIdRefreshToken
        }
    }
    
    internal static func removeToken() {
        let userDefaults = IdRefreshToken.getUserDefaults()
        userDefaults.removeObject(forKey: IdRefreshToken.idRefreshUserDefaultsKey)
        userDefaults.synchronize()
        IdRefreshToken.idRefreshInMemory = nil
    }
    
    private static func getUserDefaults() -> UserDefaults {
        return UserDefaults.standard
    }
}
