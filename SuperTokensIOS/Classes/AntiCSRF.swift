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

// TODO: verify about locking
internal class AntiCSRF {
    class AntiCSRFInfo {
        var antiCSRF: String? = nil
        var associatedAccessTokenUpdate: String? = nil
        
        init(antiCSRFToken: String, associatedAccessTokenUpdate: String) {
            antiCSRF = antiCSRFToken
            self.associatedAccessTokenUpdate = associatedAccessTokenUpdate
        }
    }
    
    private static var antiCSRFInfo: AntiCSRFInfo? = nil
    private static let antiCSRFUserDefaultsKey = SDKStorage.antiCSRFKey
    
    internal static func getToken(associatedAccessTokenUpdate: String?) -> String? {
        if associatedAccessTokenUpdate == nil {
            AntiCSRF.antiCSRFInfo = nil
            return nil
        }
        
        if AntiCSRF.antiCSRFInfo == nil {
            let antiCSRFToken = SDKStorage.get(AntiCSRF.antiCSRFUserDefaultsKey)
            if ( antiCSRFToken == nil ) {
                return nil
            }
            
            AntiCSRF.antiCSRFInfo = AntiCSRFInfo(antiCSRFToken: antiCSRFToken!, associatedAccessTokenUpdate: associatedAccessTokenUpdate!)
        } else if AntiCSRF.antiCSRFInfo?.associatedAccessTokenUpdate != nil && AntiCSRF.antiCSRFInfo?.associatedAccessTokenUpdate != associatedAccessTokenUpdate! {
            AntiCSRF.antiCSRFInfo = nil
            return AntiCSRF.getToken(associatedAccessTokenUpdate: associatedAccessTokenUpdate)
        }
        
        return AntiCSRF.antiCSRFInfo!.antiCSRF
    }
    
    @discardableResult
    internal static func setToken(antiCSRFToken: String, associatedAccessTokenUpdate: String? = nil) -> Bool {
        if associatedAccessTokenUpdate == nil {
            AntiCSRF.antiCSRFInfo = nil
            return true;
        }
        
        guard SDKStorage.set(AntiCSRF.antiCSRFUserDefaultsKey, value: antiCSRFToken) else {
            AntiCSRF.antiCSRFInfo = nil
            SDKStorage.clearSessionStorage()
            return false
        }
        
        AntiCSRF.antiCSRFInfo = AntiCSRFInfo(antiCSRFToken: antiCSRFToken, associatedAccessTokenUpdate: associatedAccessTokenUpdate!)
        return true
    }
    
    internal static func removeToken() {
        _ = SDKStorage.remove(AntiCSRF.antiCSRFUserDefaultsKey)
        AntiCSRF.antiCSRFInfo = nil
    }

    internal static func clearInMemoryCache() {
        AntiCSRF.antiCSRFInfo = nil
    }
}
