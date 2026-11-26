//
//  TrackingIdsResolverTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 03.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Tracking ids resolver", .tags(.trackingIds))
struct TrackingIdsResolverTests {

    private let trackingHost = "api-tracking.mindbox.ru"

    @Test("Zeros and nil set revoked, a real UUID sets granted")
    func zerosAndNilRevokeARealUUIDGrants() throws {
        let resolver = TrackingIdsResolver()
        let zeros = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        let id = UUID()

        resolver.update(identifier: zeros)
        #expect(resolver.state == .revoked)

        resolver.update(identifier: id)
        #expect(resolver.state == .granted(id))

        resolver.update(identifier: nil)
        #expect(resolver.state == .revoked)
    }

    @Test("Attachment exists only for the ids-bearing event types")
    func attachmentOnlyForIdsBearingTypes() {
        let resolver = TrackingIdsResolver()
        resolver.update(identifier: UUID())

        for type in [Event.Operation.installed, .infoUpdated, .trackVisit, .customEvent] {
            #expect(resolver.attachment(for: type, trackingHost: trackingHost) == nil)
        }
        #expect(resolver.attachment(for: .trackingIdsUpdated, trackingHost: trackingHost) != nil)
        #expect(resolver.attachment(for: .keepAlive, trackingHost: trackingHost) != nil)
    }

    @Test("Unknown attaches nothing, revoked attaches an empty list, granted attaches the apple id")
    func attachmentFollowsTheState() {
        let resolver = TrackingIdsResolver()
        let id = UUID()

        #expect(resolver.attachment(for: .trackingIdsUpdated, trackingHost: trackingHost) == nil)

        resolver.update(identifier: nil)
        #expect(resolver.attachment(for: .trackingIdsUpdated, trackingHost: trackingHost) == .cleared)

        resolver.update(identifier: id)
        let attachment = resolver.attachment(for: .trackingIdsUpdated, trackingHost: trackingHost)
        #expect(attachment?.ids == [TrackingId(type: "apple", value: id.uuidString)])
        #expect(attachment?.trackingHost == trackingHost)
        #expect(attachment?.carriesTrackingIds == true)
        #expect(attachment?.jsonArray == [["type": "apple", "value": id.uuidString]])
    }

    @Test("Granted without a tracking host attaches nothing, revoked still attaches the empty list")
    func grantedWithoutTrackingHostAttachesNothing() {
        let resolver = TrackingIdsResolver()

        resolver.update(identifier: UUID())
        #expect(resolver.attachment(for: .trackingIdsUpdated, trackingHost: nil) == nil)

        resolver.update(identifier: nil)
        #expect(resolver.attachment(for: .trackingIdsUpdated, trackingHost: nil) == .cleared)
    }

    @Test("The tracking host is read only for a granted id on an ids-bearing event")
    func attachmentReadsTrackingHostOnlyWhenNeeded() {
        let resolver = TrackingIdsResolver()
        var reads = 0
        func domain() -> String? {
            reads += 1
            return trackingHost
        }

        _ = resolver.attachment(for: .keepAlive, trackingHost: domain())
        resolver.update(identifier: nil)
        _ = resolver.attachment(for: .keepAlive, trackingHost: domain())
        resolver.update(identifier: UUID())
        _ = resolver.attachment(for: .installed, trackingHost: domain())
        #expect(reads == 0)

        _ = resolver.attachment(for: .keepAlive, trackingHost: domain())
        #expect(reads == 1)
    }

    @Test("Hash is stable per value and differs for the empty list")
    func hashIsStablePerValue() {
        let id = UUID()
        let first = TrackingIdsAttachment.identifiers([TrackingId(type: "apple", value: id.uuidString)], trackingHost: trackingHost)
        let otherHost = TrackingIdsAttachment.identifiers([TrackingId(type: "apple", value: id.uuidString)], trackingHost: "other.host")
        let otherId = TrackingIdsAttachment.identifiers([TrackingId(type: "apple", value: UUID().uuidString)], trackingHost: trackingHost)

        #expect(TrackingIdsAttachment.cleared.hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(first.hash == otherHost.hash)
        #expect(first.hash != otherId.hash)
        #expect(first.hash != TrackingIdsAttachment.cleared.hash)
    }

    @Test("Masking replaces every id value with a sha256-labelled prefix that matches the attachment hash and leaves the rest of the body")
    func maskingReplacesTheValueWithItsHashPrefix() throws {
        let id = UUID()
        let apple = TrackingId(type: "apple", value: id.uuidString)
        let attachment = TrackingIdsAttachment.identifiers([apple], trackingHost: trackingHost)
        let body = Data(#"{"ids":[{"type":"apple","value":"\#(id.uuidString)"}],"token":"t"}"#.utf8)

        let masked = try #require(attachment.masking(body))
        let text = try #require(String(data: masked, encoding: .utf8))

        #expect(apple.maskedValue == "sha256:" + attachment.hash.prefix(8))
        #expect(!apple.maskedValue.contains(String(id.uuidString.prefix(8))))
        #expect(text.contains(apple.maskedValue))
        #expect(!text.contains(id.uuidString))
        #expect(text.contains(#""token":"t""#))
        #expect(attachment.masking(nil) == nil)
    }
}
