//
//  MindboxEmbeddedBlockFailReason.swift
//  Mindbox
//
//  Created by vailence on 21.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Why a block could not be shown — the payload of `onFail`.
///
/// Meant for logs and analytics on the host side, not for branching: whatever the reason, the
/// container has already collapsed or switched to `errorView`. A string-backed struct rather than
/// an enum so a later SDK can add a reason without breaking an exhaustive `switch` — keep a
/// `default` when matching. The raw values are the same on every platform.
public struct MindboxEmbeddedBlockFailReason: RawRepresentable, Hashable, Sendable, CustomStringConvertible {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The content is unavailable because of the environment: the config could not be downloaded
    /// and nothing is cached, the SDK gave no answer within the block's wait budget, or the block's
    /// page could not be loaded — typically a network problem.
    public static let networkError = MindboxEmbeddedBlockFailReason(rawValue: "networkError")

    /// An error on the Mindbox side: the page loaded but never reported its content or reported
    /// something unusable, or the SDK failed inside.
    public static let internalError = MindboxEmbeddedBlockFailReason(rawValue: "internalError")

    public var description: String { rawValue }
}

// MARK: - The one place an analytics code becomes a host-facing reason

extension MindboxEmbeddedBlockFailReason {

    /// Exhaustive on purpose: a new `InAppShowFailureReason` has to decide here what the host hears.
    /// In sync with Android's `toEmbeddedBlockFailReason`.
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
