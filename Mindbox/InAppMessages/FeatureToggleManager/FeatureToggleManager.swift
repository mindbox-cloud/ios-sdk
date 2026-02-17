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

    var defaultValue: Bool {
        switch self {
        case .shouldSendInAppShowError:
            return true
        }
    }
}

final class FeatureToggleManager {
    
    public static let shared = FeatureToggleManager()
    
    private var featureToggles: Settings.FeatureToggles?

    func applyFeatureToggles(_ featureToggles: Settings.FeatureToggles?) {
        self.featureToggles = featureToggles
    }
    
    func isFeatureEnabled(_ feature: FeatureFlag) -> Bool {
        switch feature {
        case .shouldSendInAppShowError:
            return featureToggles?.shouldSendInAppShowError ?? feature.defaultValue
        }
    }
}
