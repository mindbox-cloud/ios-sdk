//
//  PushDeliveryConfirmationAnswer.swift
//  MindboxShared
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

@_spi(Internal)
public enum PushDeliveryConfirmationAnswer: Equatable, Sendable {
    case delivered
    case rejected
    case throttled
    case failed

    public init(statusCode: Int?) {
        guard let statusCode else {
            self = .failed
            return
        }
        switch statusCode {
        case 200..<300:
            self = .delivered
        case 429:
            self = .throttled
        case 300..<500:
            self = .rejected
        default:
            self = .failed
        }
    }
}
