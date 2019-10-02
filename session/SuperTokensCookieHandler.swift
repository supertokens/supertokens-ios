//
//  SuperTokensCookieHandler.swift
//  session
//
//  Created by Nemi Shah on 24/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

internal class SuperTokensCookieHandler {
    static func saveIdRefreshFromCookies(cookies: [HTTPCookie]) {
        for cookie in cookies {
            if cookie.name == SuperTokensConstants.idRefreshCookieName {
                let expiry = cookie.expiresDate!
                let currentTime = Date()
                if expiry == currentTime || expiry < currentTime {
                    IdRefreshToken.removeToken()
                } else {
                    IdRefreshToken.setToken(newIdRefreshToken: cookie.value)
                }
            }
        }
    }
}
