//
//  Error.swift
//  session
//
//  Created by Nemi Shah on 20/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

public enum SuperTokensError: Error {
    case invalidURL(String)
    case illegalAccess(String)
    case apiError(String)
}
