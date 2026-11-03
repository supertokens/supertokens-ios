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

internal class AntiCSRF {
    private static let antiCSRFUserDefaultsKey = SDKStorage.antiCSRFKey
    
    internal static func getToken(associatedAccessTokenUpdate: String?) -> String? {
        guard associatedAccessTokenUpdate != nil else { return nil }
        return SDKStorage.get(antiCSRFUserDefaultsKey)
    }
    
    @discardableResult
    internal static func setToken(antiCSRFToken: String, associatedAccessTokenUpdate: String? = nil) -> Bool {
        return SessionStateCoordinator.legacyMutation {
            guard associatedAccessTokenUpdate != nil else { return true }
            guard SDKStorage.set(antiCSRFUserDefaultsKey, value: antiCSRFToken) else {
                SDKStorage.clearSessionStorage()
                return false
            }
            return true
        }
    }
    
    @discardableResult
    internal static func removeToken() -> Bool {
        return SDKStorage.remove(antiCSRFUserDefaultsKey)
    }

    internal static func clearInMemoryCache() {
        // No independent cache; reads share the session coordinator's storage lock.
    }
}
