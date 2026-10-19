//
//  InAppTagsGating.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension FeatureToggleManager {
    static func gatedTags(_ tags: [String: String]?, isEnabled: Bool) -> [String: String]? {
        guard isEnabled, let tags, !tags.isEmpty else { return nil }
        return tags
    }

    func gatedTags(_ tags: [String: String]?) -> [String: String]? {
        Self.gatedTags(tags, isEnabled: isFeatureEnabled(.shouldSendInAppTags))
    }
}
