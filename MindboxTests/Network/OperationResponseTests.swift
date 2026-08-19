//
//  OperationResponseTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 16.07.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import Mindbox

/// Wire-contract tests for `OperationResponse`: the API returns promo
/// actions under the plural `promoActions` key, and the JSON re-encoded for the
/// hybrid bridges (`createJSON`) must use the same wire keys as the decoder —
/// otherwise a field silently vanishes between the API and the JS layer.
@Suite("OperationResponse wire contract", .tags(.decoding, .customOperation))
struct OperationResponseTests {

    /// Response shaped like the documented `get-promotions-for-customer` payload.
    private static let responseJSON = Data("""
    {
        "status": "Success",
        "promoActions": [
            {
                "ids": { "externalId": "summer-sale" },
                "name": "Summer sale",
                "description": "10% off everything",
                "startDateTimeUtc": "2026-06-01T00:00:00Z",
                "endDateTimeUtc": "2026-08-31T23:59:59Z",
                "customFields": { "testCustomField": "value" },
                "limits": [
                    {
                        "type": "personalLimit",
                        "untilDateTimeUtc": "2026-08-31T23:59:59Z",
                        "amount": { "type": "absolute", "value": 3 },
                        "used": { "amount": 1 }
                    }
                ]
            },
            { "name": "Second action" }
        ],
        "promoCode": { "isUsed": false },
        "balances": [ { "total": 100, "available": 90 } ],
        "discountCards": [ { "ids": { "number": "1234" } } ]
    }
    """.utf8)

    private func decodeResponse() throws -> OperationResponse {
        try JSONDecoder().decode(OperationResponse.self, from: Self.responseJSON)
    }

    private func reEncodedDictionary(of response: OperationResponse) throws -> [String: Any] {
        let json = try #require(response.createJSON().data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
    }

    @Test("Promo actions are decoded from the plural promoActions wire key")
    func decodesPromoActionsFromPluralKey() throws {
        let response = try decodeResponse()

        let actions = try #require(response.promoAction,
                                   "the API sends promoActions (plural); the array must not be silently dropped")
        try #require(actions.count == 2)
        #expect(actions[0].name == "Summer sale")
        #expect(actions[0].description == "10% off everything")
        #expect(actions[0].ids?["externalId"] == "summer-sale")
        #expect(actions[0].startDateTimeUtc != nil)
        #expect(actions[0].endDateTimeUtc != nil)
        #expect(actions[0].limits?.count == 1)
        #expect(actions[1].name == "Second action")
    }

    @Test("createJSON re-encodes promo actions under the promoActions wire key")
    func createJSONKeepsPluralWireKey() throws {
        let response = try decodeResponse()

        let dict = try reEncodedDictionary(of: response)

        #expect(!dict.keys.contains("promoAction"),
                "the singular key never existed on the wire and must not leak into re-encoded JSON")
        let actions = try #require(dict["promoActions"] as? [[String: Any]])
        try #require(actions.count == 2)
        #expect(actions[0]["name"] as? String == "Summer sale")
        #expect(actions[1]["name"] as? String == "Second action")
    }

    @Test("createJSON keeps every other wire key unchanged")
    func createJSONKeepsOtherWireKeys() throws {
        let response = try decodeResponse()

        let dict = try reEncodedDictionary(of: response)

        #expect(Set(dict.keys) == ["status", "promoActions", "promoCode", "balances", "discountCards"])
    }

    // The two productList shapes share one wire key on decode, but have always
    // re-encoded under their own property names (synthesized behavior). Locked
    // down here so the encode(to:) rewrite changes nothing but promoActions.
    @Test("An array productList re-encodes under the productList key")
    func productListArrayKeepsItsKey() throws {
        let response = try JSONDecoder().decode(
            OperationResponse.self,
            from: Data(#"{"status": "Success", "productList": [{"count": 2, "price": 100}]}"#.utf8))

        try #require(response.productList?.count == 1)
        let dict = try reEncodedDictionary(of: response)
        #expect((dict["productList"] as? [[String: Any]])?.count == 1)
        #expect(!dict.keys.contains("productListItems"))
    }

    @Test("An object productList re-encodes under the productListItems key")
    func productListObjectKeepsItemsKey() throws {
        let response = try JSONDecoder().decode(
            OperationResponse.self,
            from: Data(#"{"status": "Success", "productList": {"items": [{"priceForCustomer": 5}]}}"#.utf8))

        try #require(response.productListItems?.items?.count == 1)
        let dict = try reEncodedDictionary(of: response)
        #expect((dict["productListItems"] as? [String: Any]) != nil)
        #expect(!dict.keys.contains("productList"))
    }

    /// Shape of a production sync-operation response from a client report, fully
    /// anonymized: fractional seconds longer than the `.SSS` parse pattern (6 and 5
    /// digits), sibling non-Utc date keys, `timeZoneMode`, and custom fields mixing
    /// booleans with strings. All values are synthetic; the key set and the date
    /// string formats are what mirror the real payload.
    private static let productionShapedJSON = Data("""
    {
        "status": "Success",
        "promoActions": [
            {
                "ids": { "externalId": "promo-12345678" },
                "description": "First promo description",
                "endDateTime": "2026-12-31T21:00:00Z",
                "endDateTimeUtc": "2026-12-31T21:00:00Z",
                "name": "First promo",
                "startDateTime": "2026-01-02T03:04:05.256574Z",
                "startDateTimeUtc": "2026-01-02T03:04:05.256574Z",
                "timeZoneMode": "project",
                "customFields": {
                    "offerEnabled": true,
                    "offerPlacement": "top",
                    "imageUrl": "https://example.com/promo-1.png",
                    "inAppOperation": "Mobile.SomeOperation",
                    "modalVariant": "text",
                    "buttonText": "Accept",
                    "actionUrl": "https://example.com",
                    "formId": "1"
                }
            },
            {
                "ids": { "externalId": "promo-87654321" },
                "description": "Second promo description",
                "endDateTime": "2026-12-31T21:00:00Z",
                "endDateTimeUtc": "2026-12-31T21:00:00Z",
                "name": "Second promo",
                "startDateTime": "2026-01-02T03:04:06.94785Z",
                "startDateTimeUtc": "2026-01-02T03:04:06.94785Z",
                "timeZoneMode": "project",
                "customFields": {
                    "offerEnabled": true,
                    "offerPlacement": "top",
                    "imageUrl": "https://example.com/promo-2.webp",
                    "inAppOperation": "Mobile.SomeOperation",
                    "modalVariant": "image",
                    "modalImageUrl": "https://example.com/modal-2.jpg",
                    "buttonText": "Get two",
                    "actionUrl": "https://example.com",
                    "formId": "2"
                }
            }
        ]
    }
    """.utf8)

    @Test("A production-shaped payload decodes and survives re-encoding")
    func decodesProductionShapedPayload() throws {
        let response = try JSONDecoder().decode(OperationResponse.self, from: Self.productionShapedJSON)

        let actions = try #require(response.promoAction)
        try #require(actions.count == 2)
        #expect(actions[0].name == "First promo")
        #expect(actions[0].ids?["externalId"] == "promo-12345678")

        // ICU truncates fractional seconds beyond 3 digits on parse (.256574 → .256);
        // a regression to "N digits = N milliseconds" would shift this by ~4 minutes.
        let reference = try #require(ISO8601DateFormatter().date(from: "2026-01-02T03:04:05Z"))
        let start = try #require(actions[0].startDateTimeUtc).date
        #expect(abs(start.timeIntervalSince(reference)) < 1.0)

        let dict = try reEncodedDictionary(of: response)
        let encodedActions = try #require(dict["promoActions"] as? [[String: Any]])
        try #require(encodedActions.count == 2)
        // CustomFields must round-trip JSON types untouched — booleans stay booleans.
        let customFields = try #require(encodedActions[0]["customFields"] as? [String: Any])
        #expect(customFields["offerEnabled"] as? Bool == true)
        #expect(customFields["offerPlacement"] as? String == "top")
        #expect(customFields["formId"] as? String == "1")
    }

    @Test("A response without promo actions decodes with a nil field and no error")
    func decodesWithoutPromoActions() throws {
        let response = try JSONDecoder().decode(OperationResponse.self,
                                                from: Data(#"{"status": "Success"}"#.utf8))
        #expect(response.promoAction == nil)
        #expect(response.status == .success)
    }
}
