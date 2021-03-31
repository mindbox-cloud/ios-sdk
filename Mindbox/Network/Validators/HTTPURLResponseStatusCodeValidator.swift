//
//  HTTPURLStatusCodeValidator.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct HTTPURLResponseStatusCodeValidator {
    
    let statusCode: Int
    
    enum StatusCodes {
        
        case success, redirection, clientError, serverError
        
        var range: ClosedRange<Int> {
            switch self {
            case .success:
                return 200...299
            case .redirection:
                return 300...399
            case .clientError:
                return 400...499
            case .serverError:
                return 500...599
            }
        }
        
        init?(statusCode: Int) {
            switch statusCode {
            case StatusCodes.success.range:
                self = .success
            case StatusCodes.redirection.range:
                self = .redirection
            case StatusCodes.clientError.range:
                self = .clientError
            case StatusCodes.serverError.range:
                self = .serverError
            default:
                return nil
            }
        }
        
    }
    
    var isClientError: Bool {
        return StatusCodes(statusCode: statusCode) == .clientError
    }
    
    func evaluate() -> Bool {
        guard let statusCode = StatusCodes(statusCode: statusCode) else {
            return false
        }
        let evaluateCodes: [StatusCodes] = [.success, .redirection]
        return evaluateCodes.contains(statusCode)
    }
    
}
