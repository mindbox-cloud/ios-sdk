//
//  InAppShowFailure.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 19.02.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum InAppShowFailureReason: String, Codable {
    case customerSegmentRequestFailed = "customer_segmentation_request_failed"
    case geoRequestFailed = "geo_request_failed"
    case productSegmentRequestFailed = "product_segmentation_request_failed"
    case imageDownloadFailed = "image_download_failed"
    case presentationFailed = "presentation_failed"
    case webviewLoadFailed = "webview_load_failed"
    case webviewPresentationFailed = "webview_presentation_failed"
    case waitBudgetExceeded = "wait_budget_exceeded"
    case unknownError = "unknown_error"
}

/// One element of the `errors` array of `Inapp.ShowFailure`. Encodes flat, with `$type` naming the
/// kind of error and so the fields that follow — in sync with Android and the server; a new kind of
/// error is a new `$type`, never a change to an existing one.
enum InAppShowError: Encodable {
    case inapp(InAppShowFailure)
    case embeddedBlock(EmbeddedBlockShowFailure)

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .inapp(let failure):
            try container.encode("inappShowFailure", forKey: .type)
            try failure.encode(to: encoder)
        case .embeddedBlock(let failure):
            try container.encode("embeddedBlockShowFailure", forKey: .type)
            try failure.encode(to: encoder)
        }
    }
}

struct InAppShowFailure: Codable {
    let inappId: String
    let failureReason: InAppShowFailureReason
    let errorDetails: String?
    let dateTimeUtc: String
    let tags: [String: String]?
}

/// The SDK stayed silent for a block's whole wait budget: there is no in-app to name, so the place is
/// named, and `errorDetails` says what the SDK was still busy with and how long the block waited.
struct EmbeddedBlockShowFailure: Encodable {

    enum Phase: String {
        case configMissing = "config_missing"
        case resolvePending = "resolve_pending"
    }

    let placeSystemName: String
    let failureReason: InAppShowFailureReason
    let errorDetails: String?
    let dateTimeUtc: String

    init(placeSystemName: String, waited: TimeInterval, phase: Phase, dateTimeUtc: String) {
        self.placeSystemName = placeSystemName
        self.failureReason = .waitBudgetExceeded
        self.errorDetails = "phase=\(phase.rawValue); waited=\(waited.toTimeSpan())"
        self.dateTimeUtc = dateTimeUtc
    }
}
