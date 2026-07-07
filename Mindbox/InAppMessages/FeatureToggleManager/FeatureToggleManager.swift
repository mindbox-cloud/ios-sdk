//
//  FeatureToggleManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum FeatureFlag {
    case shouldSendInAppShowError
    case shouldSendInAppTags

    var defaultValue: Bool {
        switch self {
        case .shouldSendInAppShowError:
            return true
        case .shouldSendInAppTags:
            return true
        }
    }
}

final class FeatureToggleManager {

    /// Guards `featureToggles`: it is written on the config-fetch queue and read from arbitrary queues (tracking, WebView JS-bridge).
    private let lock = NSLock()
    private var featureToggles: Settings.FeatureToggles?

    func applyFeatureToggles(_ featureToggles: Settings.FeatureToggles?) {
        lock.lock()
        self.featureToggles = featureToggles
        lock.unlock()

        let flags: [String] = [
            featureToggles?.shouldSendInAppShowError.map { "MobileSdkShouldSendInAppShowError=\($0)" },
            featureToggles?.shouldSendInAppTags.map { "MobileSdkShouldSendInAppTags=\($0)" }
        ].compactMap { $0 }
        Logger.common(
            message: "[FeatureToggles] \(flags)",
            level: .debug,
            category: .inAppMessages
        )
    }

    func isFeatureEnabled(_ feature: FeatureFlag) -> Bool {
        lock.lock()
        let featureToggles = self.featureToggles
        lock.unlock()

        switch feature {
        case .shouldSendInAppShowError:
            return featureToggles?.shouldSendInAppShowError ?? feature.defaultValue
        case .shouldSendInAppTags:
            return featureToggles?.shouldSendInAppTags ?? feature.defaultValue
        }
    }
}
