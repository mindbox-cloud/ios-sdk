//
//  TrackingIdsChangeDetector.swift
//  Mindbox
//
//  Created by Sergei Semko on 03.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

final class TrackingIdsChangeDetector {
    private let trackingIdsResolver: TrackingIdsResolver
    private let trackingHostResolver: TrackingHostResolver
    private let persistenceStorage: PersistenceStorage
    private var lastEvaluatedHash: String?

    init(trackingIdsResolver: TrackingIdsResolver, trackingHostResolver: TrackingHostResolver, persistenceStorage: PersistenceStorage) {
        self.trackingIdsResolver = trackingIdsResolver
        self.trackingHostResolver = trackingHostResolver
        self.persistenceStorage = persistenceStorage
    }

    func reset() {
        lastEvaluatedHash = nil
    }

    func claimPendingChange() -> Bool {
        guard persistenceStorage.isInstalled else { return false }
        let state = trackingIdsResolver.state
        guard let attachment = trackingIdsResolver.attachment(for: .trackingIdsUpdated, trackingHost: trackingHostResolver.trackingHost) else {
            logNotAttached(state: state)
            return false
        }
        let hash = attachment.hash
        let stored = TrackingIdsRecord.reference(in: persistenceStorage)
        let reference = lastEvaluatedHash.map(TrackingIdsRecord.Reference.hash) ?? stored
        let isUnanswered = lastEvaluatedHash == nil && stored == .unconfirmed
        lastEvaluatedHash = hash
        guard reference != .hash(hash), attachment.carriesTrackingIds || reference != nil else {
            Self.log(Self.skipMessage(attachment, state: state, reference: reference))
            return false
        }
        Self.log(Self.sendingMessage(attachment, state: state, reference: reference, isUnanswered: isUnanswered))
        trackingIdsResolver.markUnconfirmed(in: persistenceStorage)
        return true
    }

    private func logNotAttached(state: TrackingIdsState) {
        if case .granted = state, let reason = trackingHostResolver.resolution.unavailableReason {
            Self.log("Tracking ids are not collected: \(reason)", level: .error)
            return
        }
        Self.log("Skip sending: the setter has not been called in this launch (state: \(state.logDescription))")
    }

    private static func skipMessage(_ attachment: TrackingIdsAttachment, state: TrackingIdsState, reference: TrackingIdsRecord.Reference?) -> String {
        guard attachment.carriesTrackingIds else {
            return "Skip sending: nothing to clear (state: \(state.logDescription), \(lastSent(reference)))"
        }
        return "Skip sending: tracking ids have not changed (state: \(state.logDescription), \(attachment.logHash))"
    }

    private static func sendingMessage(_ attachment: TrackingIdsAttachment, state: TrackingIdsState, reference: TrackingIdsRecord.Reference?, isUnanswered: Bool) -> String {
        var details = ["state: \(state.logDescription)"]
        if attachment.carriesTrackingIds {
            details.append(attachment.logHash)
        }
        guard !isUnanswered else {
            details.append("the last send got no answer")
            return "Sending tracking ids again: \(attachment.logDescription) (\(details.joined(separator: ", ")))"
        }
        details.append(lastSent(reference))
        return "Sending tracking ids: \(attachment.logDescription) (\(details.joined(separator: ", ")))"
    }

    private static func lastSent(_ reference: TrackingIdsRecord.Reference?) -> String {
        switch reference {
        case nil: return "never sent"
        case .unconfirmed?: return "the last send got no answer"
        case .hash(TrackingIdsAttachment.cleared.hash)?: return "last sent: none"
        case let .hash(hash)?: return "last sent: sha256 " + hash.prefix(8)
        }
    }

    private static func log(_ message: String, level: LogLevel = .debug) {
        Logger.common(message: "[TrackingIds] " + message, level: level, category: .general)
    }
}
