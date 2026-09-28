//
//  MindboxEmbeddedBlockFailReasonTests.swift
//  MindboxTests
//
//  Created by vailence on 21.09.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("Embedded block fail reason", .tags(.embeddedBlocks))
struct MindboxEmbeddedBlockFailReasonTests {

    /// The analytics vocabulary is internal; the host hears one of two words, the same as on Android.
    /// Every code has to land somewhere, so a new code is a compile error here until it is placed.
    @Test("Every analytics code maps to exactly one host-facing reason",
          arguments: [(InAppShowFailureReason.waitBudgetExceeded, MindboxEmbeddedBlockFailReason.networkError),
                      (.webviewLoadFailed, .networkError),
                      (.presentationFailed, .internalError),
                      (.webviewPresentationFailed, .internalError),
                      (.unknownError, .internalError),
                      (.customerSegmentRequestFailed, .internalError),
                      (.geoRequestFailed, .internalError),
                      (.productSegmentRequestFailed, .internalError),
                      (.imageDownloadFailed, .internalError)])
    func everyCodeHasAReason(code: InAppShowFailureReason, reason: MindboxEmbeddedBlockFailReason) {
        #expect(MindboxEmbeddedBlockFailReason(code) == reason)
    }

    @Test("The two reasons are distinct and spelled as Android spells them")
    func reasonsAreDistinct() {
        let reasons: [MindboxEmbeddedBlockFailReason] = [.networkError, .internalError]

        #expect(Set(reasons).count == 2)
        #expect(reasons.map(\.rawValue) == ["networkError", "internalError"])
    }

    /// Wrappers forward the reason as a string; a host prints it. Both must read the same word.
    @Test("description is the raw value")
    func descriptionIsTheRawValue() {
        for reason in [MindboxEmbeddedBlockFailReason.networkError, .internalError] {
            #expect(reason.description == reason.rawValue)
        }
    }

    /// A reason from a later SDK survives the trip: it is not an enum case that has to exist.
    @Test("An unknown reason round-trips through its raw value")
    func unknownReasonRoundTrips() {
        let future = MindboxEmbeddedBlockFailReason(rawValue: "somethingNew")

        #expect(future.rawValue == "somethingNew")
        #expect(future != .internalError)
    }
}
