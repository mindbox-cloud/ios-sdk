//
//  FeatureToggleManager.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol FeatureToggleManagerProtocol {
    func applyFeatureToggles(_ featureToggles: Settings.FeatureToggles?)
    func shouldSendInAppShowError() -> Bool
}

final class FeatureToggleManager: FeatureToggleManagerProtocol {
    
    public static let shared = FeatureToggleManager()
    
    private var featureToggles: Settings.FeatureToggles? = nil

    func applyFeatureToggles(_ featureToggles: Settings.FeatureToggles?) {
        self.featureToggles = featureToggles
    }
    
    func shouldSendInAppShowError() -> Bool {
        featureToggles?.shouldSendInAppShowError ?? true
    }
}
