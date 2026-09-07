//
//  InappShowFailureManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.02.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InappShowFailureManagerProtocol {
    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?)

    /// The buffer answers "why was nothing shown": a pass that picked nothing sends it, a pass that
    /// picked something drops it (in sync with Android).
    func sendFailures()
    func clearFailures()

    /// The SDK never answered a block within its wait budget — a failure with no in-app to pin it on, so
    /// it names the place instead. Sent at once, past the buffer, like the other block failures.
    func sendWaitBudgetExceeded(place: String, waited: TimeInterval, phase: EmbeddedBlockShowFailure.Phase)

    /// Sends a block's failure at once, without joining the buffer the selection pass fills, and once
    /// per in-app and reason per session: a block that fails the same way on every return to the
    /// screen reports it a single time. The overlay's failures go through the buffer.
    ///
    /// The buffer keeps a single failure per in-app id and only lets the three targeting reasons
    /// replace each other, so a failure that does not belong to a selection pass would be dropped
    /// whenever that id already has one buffered. In sync with Android, whose block failures also
    /// bypass their collected list.
    func sendBlockFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?)
}

final class InappShowFailureManager: InappShowFailureManagerProtocol {
    /// Backend payload limit for errorDetails.
    static let errorDetailsLimit = 1000

    private struct InAppShowErrorsBody: Encodable {
        let errors: [InAppShowError]
    }

    private let databaseRepository: DatabaseRepositoryProtocol
    private let featureToggleManager: FeatureToggleManager
    private let queue = DispatchQueue(label: "com.Mindbox.InappShowFailureManager.queue")
    private var failures: [InAppShowFailure] = []

    init(databaseRepository: DatabaseRepositoryProtocol,
         featureToggleManager: FeatureToggleManager) {
        self.databaseRepository = databaseRepository
        self.featureToggleManager = featureToggleManager
    }
    
    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(message: "[InappShowFailureManager] addFailure ignored, feature is disabled", category: .inAppMessages)
            return
        }

        let gatedTags = featureToggleManager.gatedTags(tags)
        let truncatedDetails = truncatedDetails(details, inappId: inappId)

        queue.async { [self] in
            if isNetworkOutage(reason),
               SessionTemporaryStorage.shared.ledger.reportedFailures.contains(ReportedFailure(inappId: inappId, reason: reason.rawValue)) {
                Logger.common(message: "[InappShowFailureManager] Ignore failure already reported this session. inappId=\(inappId), reason=\(reason.rawValue)",
                              level: .debug, category: .inAppMessages)
                return
            }

            if let existingIndex = failures.firstIndex(where: { $0.inappId == inappId }) {
                guard shouldReplaceFailure(currentReason: failures[existingIndex].failureReason, newReason: reason) else {
                    let existingReason = failures[existingIndex].failureReason.rawValue
                    Logger.common(
                        message: "[InappShowFailureManager] Ignore failure update: existing reason has higher priority. " +
                            "inappId=\(inappId), existing=\(existingReason), incoming=\(reason.rawValue)",
                        category: .inAppMessages
                    )
                    return
                }
                failures[existingIndex] = makeFailure(inappId: inappId, reason: reason, details: truncatedDetails, tags: gatedTags)
                Logger.common(message: "[InappShowFailureManager] Failure reason updated. inappId=\(inappId), reason=\(reason.rawValue)",
                              category: .inAppMessages)
                return
            }

            failures.append(makeFailure(inappId: inappId, reason: reason, details: truncatedDetails, tags: gatedTags))
        }
    }
    
    func sendBlockFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(message: "[InappShowFailureManager] sendBlockFailure ignored, feature is disabled", category: .inAppMessages)
            return
        }

        let failure = makeFailure(inappId: inappId,
                                  reason: reason,
                                  details: truncatedDetails(details, inappId: inappId),
                                  tags: featureToggleManager.gatedTags(tags))

        queue.async { [self] in
            guard let sent = enqueueOncePerSession([failure], where: { _ in true }) else { return }

            guard !sent.isEmpty else {
                Logger.common(message: "[InappShowFailureManager] Ignore failure already reported this session. inappId=\(inappId), reason=\(reason.rawValue)",
                              level: .debug, category: .inAppMessages)
                return
            }

            Logger.common(message: "[InappShowFailureManager] Inapp.ShowFailure event sent at once. inappId=\(inappId), reason=\(reason.rawValue)",
                          category: .inAppMessages)
        }
    }

    private func truncatedDetails(_ details: String?, inappId: String) -> String? {
        details.map { original in
            let truncated = original.truncated(toUTF8ByteLimit: Self.errorDetailsLimit)
            if truncated != original {
                Logger.common(
                    message: "[InappShowFailureManager] errorDetails truncated to \(truncated.utf8.count) bytes (limit \(Self.errorDetailsLimit)). inappId=\(inappId)",
                    level: .debug,
                    category: .inAppMessages
                )
            }
            return truncated
        }
    }

    /// Must be called on `queue`. Records the failures not yet reported this session and enqueues them as one
    /// event, the check and the record under one lock hold; a failed enqueue un-records them, so the retry is
    /// not suppressed as a duplicate. Nil when the enqueue failed.
    private func enqueueOncePerSession(_ candidates: [InAppShowFailure],
                                       where isReportedOnce: (InAppShowFailureReason) -> Bool) -> [InAppShowFailure]? {
        let toSend = SessionTemporaryStorage.shared.$ledger.mutate { ledger in
            candidates.filter { failure in
                guard isReportedOnce(failure.failureReason) else { return true }

                return ledger.recordFailure(failure.inappId, reason: failure.failureReason.rawValue)
            }
        }

        guard !toSend.isEmpty else { return [] }

        guard enqueue(toSend.map(InAppShowError.inapp)) else {
            SessionTemporaryStorage.shared.$ledger.mutate { ledger in
                toSend.forEach { ledger.reportedFailures.remove(ReportedFailure(inappId: $0.inappId, reason: $0.failureReason.rawValue)) }
            }
            return nil
        }

        return toSend
    }

    /// Must be called on `queue`.
    private func enqueue(_ errors: [InAppShowError]) -> Bool {
        let eventBody = InAppShowErrorsBody(errors: errors)
        let event = Event(type: .inAppShowFailureEvent, body: BodyEncoder(encodable: eventBody).body)

        do {
            try databaseRepository.create(event: event)
            return true
        } catch {
            Logger.common(
                message: "[InappShowFailureManager] Failed to enqueue Inapp.ShowFailure event: \(error)",
                level: .error,
                category: .inAppMessages
            )
            return false
        }
    }

    func sendFailures() {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(
                message: "[InappShowFailureManager] sendFailures ignored, feature is disabled",
                level: .debug,
                category: .inAppMessages
            )
            return
        }
        
        queue.async { [self] in
            guard !failures.isEmpty else { return }

            // A network outage is one report per session, in sync with Android.
            guard let sent = enqueueOncePerSession(failures, where: isNetworkOutage) else { return }

            if sent.count < failures.count {
                Logger.common(message: "[InappShowFailureManager] Suppressed \(failures.count - sent.count) failure(s) already reported this session",
                              level: .debug, category: .inAppMessages)
            }
            if !sent.isEmpty {
                Logger.common(message: "[InappShowFailureManager] Inapp.ShowFailure event sent with \(sent.count) failure(s)",
                              category: .inAppMessages)
            }
            failures.removeAll()
        }
    }
    
    func clearFailures() {
        queue.async { [self] in
            guard !failures.isEmpty else { return }

            Logger.common(message: "[InappShowFailureManager] Dropping \(failures.count) buffered failure(s): the pass showed something",
                          level: .debug, category: .inAppMessages)
            failures.removeAll()
        }
    }

    func sendWaitBudgetExceeded(place: String, waited: TimeInterval, phase: EmbeddedBlockShowFailure.Phase) {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(message: "[InappShowFailureManager] sendWaitBudgetExceeded ignored, feature is disabled", category: .inAppMessages)
            return
        }

        let failure = EmbeddedBlockShowFailure(placeSystemName: place,
                                               waited: waited,
                                               phase: phase,
                                               dateTimeUtc: Date().toString(withFormat: .utc))

        queue.async { [self] in
            guard enqueue([.embeddedBlock(failure)]) else { return }

            Logger.common(message: "[InappShowFailureManager] Inapp.ShowFailure event sent for place '\(place)': the SDK stayed silent for \(waited.toTimeSpan()) (\(phase.rawValue))",
                          category: .inAppMessages)
        }
    }

    private func makeFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) -> InAppShowFailure {
        InAppShowFailure(
            inappId: inappId,
            failureReason: reason,
            errorDetails: details,
            dateTimeUtc: Date().toString(withFormat: .utc),
            tags: tags
        )
    }

    private func shouldReplaceFailure(currentReason: InAppShowFailureReason, newReason: InAppShowFailureReason) -> Bool {
        guard
            let currentPriority = targetingFailurePriority(for: currentReason),
            let newPriority = targetingFailurePriority(for: newReason)
        else {
            return false
        }

        return newPriority > currentPriority
    }

    private func isNetworkOutage(_ reason: InAppShowFailureReason) -> Bool {
        switch reason {
        case .customerSegmentRequestFailed, .geoRequestFailed, .productSegmentRequestFailed, .imageDownloadFailed:
            return true
        default:
            return false
        }
    }

    private func targetingFailurePriority(for reason: InAppShowFailureReason) -> Int? {
        switch reason {
        case .customerSegmentRequestFailed:
            return 3
        case .geoRequestFailed:
            return 2
        case .productSegmentRequestFailed:
            return 1
        default:
            return nil
        }
    }
}
