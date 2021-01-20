//
//  MindBoxErrors.swift
//  MindBox
//
//  Created by Mikhail Barilov on 19.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
extension MindBox {

    public enum Errors: LocalizedError {
        case invalidConfiguration(reason: String? = nil, suggestion: String? = nil)
        case invalidAccess(reason: String? = nil, suggestion: String? = nil)

        public var errorDescription: String? { get {
                switch self {
                case .invalidConfiguration:
                    return "MBConfiguration init was canceled."
                case .invalidAccess:
                    return "Access denied"
                }
            }
        }

        public var failureReason: String? { get {
                switch self {
                case .invalidConfiguration(let reason, _):
                    return reason
                case .invalidAccess(let reason, _):
                    return reason
                }
            }
        }

        public var recoverySuggestion: String? { get {
                switch self {
                case .invalidConfiguration(_, let suggestion):
                    return suggestion
                case .invalidAccess(_, let suggestion):
                    return suggestion
                }
            }
        }

    }

}

