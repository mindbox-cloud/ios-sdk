//
//  MindboxEmbeddedBlockFailReason.swift
//  Mindbox
//
//  Created by vailence on 21.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Why a block failed, for logs and analytics. Later SDK versions may add reasons.
public struct MindboxEmbeddedBlockFailReason: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The SDK could not get the content, typically because of the network or the block's `timeout`.
    public static let networkError = MindboxEmbeddedBlockFailReason(rawValue: "networkError")

    /// The campaign at the place is not a valid embedded block, or its page did not report its content
    /// in time or in a form the SDK can read.
    public static let internalError = MindboxEmbeddedBlockFailReason(rawValue: "internalError")

    public var description: String { rawValue }
}

// MARK: - The one place an analytics code becomes a host-facing reason

extension MindboxEmbeddedBlockFailReason {

    init(_ reason: InAppShowFailureReason) {
        switch reason {
        case .waitBudgetExceeded, .webviewLoadFailed:
            self = .networkError
        case .presentationFailed,
             .webviewPresentationFailed,
             .unknownError,
             .customerSegmentRequestFailed,
             .geoRequestFailed,
             .productSegmentRequestFailed,
             .imageDownloadFailed:
            self = .internalError
        }
    }
}
