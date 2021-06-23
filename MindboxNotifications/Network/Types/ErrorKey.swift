//
//  Error.swift
//  URLSessionAPIServices
//
//  Created by Yusuf Demirci on 13.04.2020.
//  Copyright © 2020 Yusuf Demirci. All rights reserved.
//

import Foundation

enum ErrorKey: String {
    case general = "Error_general"
    case parsing = "Error_parsing"
    case invalidConfiguration = "Invalid_Configuration"
    case unknownStatusKey = "Error_unknown_status_key"
    case serverError = "Server_error"
    case invalidAccess = "Invalid_Access"
}
