//
//  InAppTagsGatingTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("gatedTags pure function tests")
struct InAppTagsGatingTests {

    @Test("Returns tags unchanged when feature is enabled and tags are non-empty", .tags(.inAppTags))
    func returnsTagsWhenEnabled() {
        let tags: [String: String]? = ["templateType": "Popup"]
        #expect(tags.gatedTags(isTagsFeatureEnabled: true) == tags)
    }

    @Test("Returns nil when feature is disabled, even with non-empty tags", .tags(.inAppTags))
    func returnsNilWhenDisabled() {
        let tags: [String: String]? = ["templateType": "Popup"]
        #expect(tags.gatedTags(isTagsFeatureEnabled: false) == nil)
    }

    @Test("Returns nil when tags are nil, regardless of feature state", .tags(.inAppTags))
    func returnsNilWhenTagsNil() {
        let tags: [String: String]? = nil
        #expect(tags.gatedTags(isTagsFeatureEnabled: true) == nil)
        #expect(tags.gatedTags(isTagsFeatureEnabled: false) == nil)
    }

    @Test("Returns nil when tags are empty, even when feature is enabled", .tags(.inAppTags))
    func returnsNilWhenTagsEmpty() {
        let tags: [String: String]? = [:]
        #expect(tags.gatedTags(isTagsFeatureEnabled: true) == nil)
    }
}
