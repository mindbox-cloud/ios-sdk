//
//  InAppTagsGating.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension FeatureToggleManager {
    /// Returns `tags` when `isEnabled` is `true` and the dictionary is non-empty, `nil` otherwise.
    static func gatedTags(_ tags: [String: String]?, isEnabled: Bool) -> [String: String]? {
        guard isEnabled, let tags, !tags.isEmpty else { return nil }
        return tags
    }

    /// Returns `tags` when `MobileSdkShouldSendInAppTags` is enabled and the dictionary is non-empty, `nil` otherwise.
    func gatedTags(_ tags: [String: String]?) -> [String: String]? {
        Self.gatedTags(tags, isEnabled: isFeatureEnabled(.shouldSendInAppTags))
    }
}
