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
            Logger.common(
                message: "[InappShowFailureManager] addFailure ignored, feature is disabled",
                level: .debug,
                category: .inAppMessages
            )
            return
        }
        
        queue.async { [self] in
            guard !failures.contains(where: { $0.inappId == inappId }) else {
                return
            }

            let failure = InAppShowFailure(
                inappId: inappId,
                failureReason: reason,
                errorDetails: details,
                dateTimeUtc: Date().toString(withFormat: .utc)
            )

            failures.append(failure)
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
}
