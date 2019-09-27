//
//  AntiCSRF.swift
//  session
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

// TODO: verify about locking
internal class AntiCSRF {
    class AntiCSRFInfo {
        var antiCSRF: String? = nil
        var idRefreshToken: String? = nil
        
        init(antiCSRFToken: String, associatedIdRefreshToken: String) {
            antiCSRF = antiCSRFToken
            idRefreshToken = associatedIdRefreshToken
        }
    }
    
    private static var antiCSRFInfo: AntiCSRFInfo? = nil
    private static let antiCSRFUserDefaultsKey = "supertokens-android-anticsrf-key"
    
    internal static func getToken(associatedIdRefreshToken: String?) -> String? {
        if associatedIdRefreshToken == nil {
            AntiCSRF.antiCSRFInfo = nil
            return nil
        }
        
        if AntiCSRF.antiCSRFInfo == nil {
            let userDefaults = AntiCSRF.getUserDefaults()
            let antiCSRFToken = userDefaults.string(forKey: AntiCSRF.antiCSRFUserDefaultsKey)
            if ( antiCSRFToken == nil ) {
                return nil
            }
            
            AntiCSRF.antiCSRFInfo = AntiCSRFInfo(antiCSRFToken: antiCSRFToken!, associatedIdRefreshToken: associatedIdRefreshToken!)
        } else if AntiCSRF.antiCSRFInfo?.idRefreshToken != nil && AntiCSRF.antiCSRFInfo?.idRefreshToken != associatedIdRefreshToken! {
            AntiCSRF.antiCSRFInfo = nil
            return AntiCSRF.getToken(associatedIdRefreshToken: associatedIdRefreshToken)
        }
        
        return AntiCSRF.antiCSRFInfo!.antiCSRF
    }
    
    internal static func setToken(antiCSRFToken: String, associatedIdRefreshToken: String? = nil) {
        if associatedIdRefreshToken == nil {
            AntiCSRF.antiCSRFInfo = nil
            return;
        }
        
        let userDefaults = AntiCSRF.getUserDefaults()
        userDefaults.set(antiCSRFToken, forKey: AntiCSRF.antiCSRFUserDefaultsKey)
        userDefaults.synchronize()
        
        AntiCSRF.antiCSRFInfo = AntiCSRFInfo(antiCSRFToken: antiCSRFToken, associatedIdRefreshToken: associatedIdRefreshToken!)
    }
    
    internal static func removeToken() {
        let userDefaults = AntiCSRF.getUserDefaults()
        userDefaults.removePersistentDomain(forName: AntiCSRF.antiCSRFUserDefaultsKey)
        userDefaults.synchronize()
    }
    
    private static func getUserDefaults() -> UserDefaults {
        return UserDefaults.standard
    }
}
