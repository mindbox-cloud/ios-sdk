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
    func sendFailures()

    /// Sends one failure at once, without joining the buffer the selection pass fills.
    ///
    /// The buffer keeps a single failure per in-app id and only lets the three targeting reasons
    /// replace each other, so a failure that does not belong to a selection pass would be dropped
    /// whenever that id already has one buffered. In sync with Android, whose block failures also
    /// bypass their collected list.
    func sendFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?)
}

final class InappShowFailureManager: InappShowFailureManagerProtocol {
    /// Backend payload limit for errorDetails.
    static let errorDetailsLimit = 1000

    private struct InAppShowFailuresBody: Codable {
        let failures: [InAppShowFailure]
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
    
    func sendFailure(inappId: String, reason: InAppShowFailureReason, details: String?, tags: [String: String]?) {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(message: "[InappShowFailureManager] sendFailure ignored, feature is disabled", category: .inAppMessages)
            return
        }

        let failure = makeFailure(inappId: inappId,
                                  reason: reason,
                                  details: truncatedDetails(details, inappId: inappId),
                                  tags: featureToggleManager.gatedTags(tags))

        queue.async { [self] in
            guard enqueue([failure]) else { return }

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

    /// Must be called on `queue`.
    private func enqueue(_ failures: [InAppShowFailure]) -> Bool {
        let eventBody = InAppShowFailuresBody(failures: failures)
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
            guard !failures.isEmpty, enqueue(failures) else {
                return
            }

            Logger.common(message: "[InappShowFailureManager] Inapp.ShowFailure event sent with \(failures.count) failure(s)",
                          category: .inAppMessages)
            failures.removeAll()
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
