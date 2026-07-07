//
//  InAppTagsGating.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension Optional where Wrapped == [String: String] {
    /// Returns `self` when the tags feature is enabled and the dictionary is non-empty, `nil` otherwise.
    func gatedTags(isTagsFeatureEnabled: Bool) -> [String: String]? {
        guard isTagsFeatureEnabled, let self, !self.isEmpty else { return nil }
        return self
    }
}

extension FeatureToggleManager {
    /// Returns `tags` when `MobileSdkShouldSendInAppTags` is enabled and the dictionary is non-empty, `nil` otherwise.
    func gatedTags(_ tags: [String: String]?) -> [String: String]? {
        tags.gatedTags(isTagsFeatureEnabled: isFeatureEnabled(.shouldSendInAppTags))
    }
}
