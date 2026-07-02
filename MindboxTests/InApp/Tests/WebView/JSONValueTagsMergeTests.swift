//
//  JSONValueTagsMergeTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 01.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("JSONValue.mergingInAppTags tests")
struct JSONValueTagsMergeTests {

    @Test("Sets tags directly when body has no tags key", .tags(.inAppTags, .webView))
    func setsTagsWhenAbsent() {
        let body: JSONValue = .object(["viewProduct": .string("value")])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup"], into: body)

        guard case .object(let dict) = merged else {
            Issue.record("Expected merged body to be an object")
            return
        }
        #expect(dict["tags"] == .object(["templateType": .string("Popup")]))
        #expect(dict["viewProduct"] == .string("value"))
    }

    @Test("Sets tags directly when existing tags value is null", .tags(.inAppTags, .webView))
    func setsTagsWhenNull() {
        let body: JSONValue = .object(["tags": .null])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup"], into: body)

        guard case .object(let dict) = merged else {
            Issue.record("Expected merged body to be an object")
            return
        }
        #expect(dict["tags"] == .object(["templateType": .string("Popup")]))
    }

    @Test("Adds only missing keys when tags already an object, client keys win", .tags(.inAppTags, .webView))
    func mergesMissingKeysOnly() {
        let body: JSONValue = .object(["tags": .object(["campaign": .string("client-campaign")])])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup", "campaign": "server-campaign"], into: body)

        guard case .object(let dict) = merged,
              case .object(let tags) = dict["tags"] else {
            Issue.record("Expected merged body's tags to be an object")
            return
        }
        #expect(tags["campaign"] == .string("client-campaign"))
        #expect(tags["templateType"] == .string("Popup"))
    }

    @Test("Leaves body untouched when existing tags value is not an object", .tags(.inAppTags, .webView))
    func leavesNonObjectTagsUntouched() {
        let body: JSONValue = .object(["tags": .string("client-string")])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup"], into: body)

        #expect(merged == body)
    }

    @Test("Leaves array-valued tags untouched", .tags(.inAppTags, .webView))
    func leavesArrayTagsUntouched() {
        let body: JSONValue = .object(["tags": .array([.string("a")])])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup"], into: body)

        #expect(merged == body)
    }

    @Test("Returns body unchanged when tags are nil", .tags(.inAppTags, .webView))
    func returnsBodyUnchangedWhenTagsNil() {
        let body: JSONValue = .object(["viewProduct": .string("value")])
        let merged = JSONValue.mergingInAppTags(nil, into: body)

        #expect(merged == body)
    }

    @Test("Returns body unchanged when tags are empty", .tags(.inAppTags, .webView))
    func returnsBodyUnchangedWhenTagsEmpty() {
        let body: JSONValue = .object(["viewProduct": .string("value")])
        let merged = JSONValue.mergingInAppTags([:], into: body)

        #expect(merged == body)
    }

    @Test("Returns body unchanged when body root is not an object", .tags(.inAppTags, .webView))
    func returnsBodyUnchangedWhenRootIsNotObject() {
        let body: JSONValue = .array([.string("a")])
        let merged = JSONValue.mergingInAppTags(["templateType": "Popup"], into: body)

        #expect(merged == body)
    }
}
