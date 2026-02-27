//
//  InappShowFailureManager.swift
//  Mindbox
//
//  Created by Cursor on 19.02.2026.
//

import Foundation
import MindboxLogger

protocol InappShowFailureManagerProtocol {
    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?)
    func clearFailures()
    func sendFailures()
}

final class InappShowFailureManager: InappShowFailureManagerProtocol {
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
    
    func addFailure(inappId: String, reason: InAppShowFailureReason, details: String?) {
        guard featureToggleManager.isFeatureEnabled(.shouldSendInAppShowError) else {
            Logger.common(message: "[InappShowFailureManager] addFailure ignored, feature is disabled",
                          level: .debug,
                          category: .inAppMessages)
            return
        }
        
        queue.async { [self] in
            if let existingIndex = failures.firstIndex(where: { $0.inappId == inappId }) {
                guard shouldReplaceFailure(currentReason: failures[existingIndex].failureReason, newReason: reason) else {
                    Logger.common(
                        message: "[InappShowFailureManager] Ignore failure update: existing reason has higher priority. inappId=\(inappId), existing=\(failures[existingIndex].failureReason.rawValue), incoming=\(reason.rawValue)",
                        level: .debug,
                        category: .inAppMessages
                    )
                    return
                }
                failures[existingIndex] = makeFailure(inappId: inappId, reason: reason, details: details)
                Logger.common(
                    message: "[InappShowFailureManager] Failure reason updated. inappId=\(inappId), reason=\(reason.rawValue)",
                    level: .debug,
                    category: .inAppMessages
                )
                return
            }
            
            failures.append(makeFailure(inappId: inappId, reason: reason, details: details))
        }
    }
    
    func clearFailures() {
        queue.async { [self] in
            failures.removeAll()
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
            guard !failures.isEmpty else {
                return
            }
            let eventBody = InAppShowFailuresBody(failures: failures)
            let event = Event(type: .inAppShowFailureEvent, body: BodyEncoder(encodable: eventBody).body)

            do {
                try databaseRepository.create(event: event)
                failures.removeAll()
            } catch {
                Logger.common(
                    message: "[InappShowFailureManager] Failed to enqueue Inapp.ShowFailure event: \(error)",
                    level: .error,
                    category: .inAppMessages
                )
            }
        }
    }
    
    private func makeFailure(inappId: String, reason: InAppShowFailureReason, details: String?) -> InAppShowFailure {
        InAppShowFailure(
            inappId: inappId,
            failureReason: reason,
            errorDetails: details,
            dateTimeUtc: Date().toString(withFormat: .utc)
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
