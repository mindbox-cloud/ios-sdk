//
//  InAppShowFailure.swift
//  Mindbox
//
//  Created by Cursor on 19.02.2026.
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
    case unknownError = "unknown_error"
}

struct InAppShowFailure: Codable {
    let inappId: String
    let failureReason: InAppShowFailureReason
    let errorDetails: String?
    let dateTimeUtc: String
}
