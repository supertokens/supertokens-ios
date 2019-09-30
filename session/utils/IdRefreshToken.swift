//
//  IdRefreshToken.swift
//  session
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

// TODO: verify about locking
internal class IdRefreshToken {
    private static var idRefreshInMemory: String? = nil
    private static var idRefreshUserDefaultsKey = "supertokens-ios-idrefreshtoken-key"
    
    internal static func getToken() -> String? {
        if ( IdRefreshToken.idRefreshInMemory == nil ) {
            idRefreshInMemory = IdRefreshToken.getUserDefaults().string(forKey: IdRefreshToken.idRefreshUserDefaultsKey)
        }
        return IdRefreshToken.idRefreshInMemory
    }
    
    internal static func setToken(newIdRefreshToken: String) {
        let userDefaults = IdRefreshToken.getUserDefaults()
        userDefaults.set(newIdRefreshToken, forKey: IdRefreshToken.idRefreshUserDefaultsKey)
        userDefaults.synchronize()
        IdRefreshToken.idRefreshInMemory = newIdRefreshToken
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
