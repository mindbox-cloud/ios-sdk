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
    case shouldPrewarmInAppWebView
    case shouldCacheInAppWebView

    var defaultValue: Bool {
        switch self {
        case .shouldSendInAppShowError, .shouldPrewarmInAppWebView, .shouldCacheInAppWebView:
            return true
        }
    }
}

/// Holds the toggles applied from a freshly downloaded config. The WebView flags
/// (`shouldPrewarmInAppWebView`, `shouldCacheInAppWebView`) are deliberately read
/// config-scoped by their consumers instead (each prewarm stage reads the config it works
/// with; the data store latches from the config cache) — those reads happen before any
/// fresh config can be applied here.
final class FeatureToggleManager {

    private var featureToggles: Settings.FeatureToggles?

    func applyFeatureToggles(_ featureToggles: Settings.FeatureToggles?) {
        self.featureToggles = featureToggles
        let flags: [String] = [
            featureToggles?.shouldSendInAppShowError.map { "MobileSdkShouldSendInAppShowError=\($0)" },
            featureToggles?.shouldPrewarmInAppWebView.map { "MobileSdkShouldPrewarmInAppWebView=\($0)" },
            featureToggles?.shouldCacheInAppWebView.map { "MobileSdkShouldCacheInAppWebView=\($0)" }
        ].compactMap { $0 }
        Logger.common(
            message: "[FeatureToggles] \(flags)",
            level: .debug,
            category: .inAppMessages
        )
    }
    
    func isFeatureEnabled(_ feature: FeatureFlag) -> Bool {
        switch feature {
        case .shouldSendInAppShowError:
            return featureToggles?.shouldSendInAppShowError ?? feature.defaultValue
        case .shouldPrewarmInAppWebView:
            return featureToggles?.shouldPrewarmInAppWebView ?? feature.defaultValue
        case .shouldCacheInAppWebView:
            return featureToggles?.shouldCacheInAppWebView ?? feature.defaultValue
        }
    }
}
