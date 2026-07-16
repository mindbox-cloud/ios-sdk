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

/// Wire-contract tests for `OperationResponse` (MOBILE-303): the API returns promo
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
    // down here so the MOBILE-303 encode(to:) rewrite changes nothing but promoActions.
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

    @Test("A response without promo actions decodes with a nil field and no error")
    func decodesWithoutPromoActions() throws {
        let response = try JSONDecoder().decode(OperationResponse.self,
                                                from: Data(#"{"status": "Success"}"#.utf8))
        #expect(response.promoAction == nil)
        #expect(response.status == .success)
    }
}
