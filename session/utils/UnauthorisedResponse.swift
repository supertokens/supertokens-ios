//
//  UnauthorisedResponse.swift
//  session
//
//  Created by Nemi Shah on 24/09/19.
//  Copyright © 2019 SuperTokens. All rights reserved.
//

import Foundation

internal class UnauthorisedResponse {
    internal enum UnauthorisedStatus {
        case SESSION_EXPIRED
        case API_ERROR
        case RETRY
    }
    let status: UnauthorisedStatus
    let error: Error?
    
    init(status: UnauthorisedStatus, error: Error? = nil) {
        self.status = status
        self.error = error
    }
}
