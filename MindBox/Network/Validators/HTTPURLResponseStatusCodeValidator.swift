//
//  HTTPURLStatusCodeValidator.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

struct HTTPURLResponseStatusCodeValidator {
    
    let statusCode: Int
    
    enum StatusCodes {
        
        case success, failure
        
        init?(statusCode: Int) {
            switch statusCode {
            case 200...399:
                self = .success
            case 400...599:
                self = .failure
            default:
                return nil
            }
        }
        
    }
    
    func evaluate() -> Bool {
        return StatusCodes(statusCode: statusCode) == .success
    }
    
}
