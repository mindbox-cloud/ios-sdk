//
//  MindboxEmbeddedBlockFailReason.swift
//  Mindbox
//
//  Created by vailence on 21.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Why a block failed, passed to
/// ``MindboxEmbeddedBlockViewDelegate/mindboxEmbeddedBlockViewDidFail(_:reason:)`` and to `onFail`.
///
/// Meant for logs and analytics: by the time it arrives, the block has already collapsed or shown its
/// error view. Later SDK versions may add reasons, so keep a `default` when matching.
public struct MindboxEmbeddedBlockFailReason: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The content could not be obtained, typically because of the network: the SDK has no config, it
    /// did not choose the content within the block's `timeout`, the block's page failed to load, or
    /// segment or geo data the place's targeting needs could not be fetched.
    public static let networkError = MindboxEmbeddedBlockFailReason(rawValue: "networkError")

    /// The block's campaign or page did not work: the campaign at the place is not a valid embedded
    /// block, or its page, download included, took too long to report its content or reported it in a
    /// form the SDK cannot read.
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
