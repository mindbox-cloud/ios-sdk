//
//  InAppConfigStub.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 21.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

final class InAppConfigStub {

    func getCategoryID_Substring() throws -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .substring, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getCategoryID_notSubstring() throws -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .notSubstring, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getCategoryID_startWith() throws -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .startsWith, value: "oot")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getCategoryID_endWith() throws -> ConfigResponse {
        let categoryIdTargeting = CategoryIDTargeting(kind: .endsWith, value: "ots")
        let targeting = Targeting.viewProductCategoryId(categoryIdTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getCategoryIDIn_Any() throws -> ConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(
            kind: .any,
            values: [
                .init(id: "testik2", name: "System1C"),
                .init(id: "81", name: "TestSite")
            ]
        )
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getCategoryIDIn_None() throws -> ConfigResponse {
        let categoryIdInTargeting = CategoryIDInTargeting(
            kind: .none,
            values: [.init(id: "testik2", name: "System1C"),
                     .init(id: "81", name: "TestSite")
            ]
        )
        let targeting = Targeting.viewProductCategoryIdIn(categoryIdInTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewCategory)
    }

    func getProductID_substring() throws -> ConfigResponse {
        let productIDTargeting = ProductIDTargeting(kind: .substring, value: "oot")
        let targeting = Targeting.viewProductId(productIDTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }

    func getProductID_notSubstring() throws -> ConfigResponse {
        let productIDTargeting = ProductIDTargeting(kind: .notSubstring, value: "oot")
        let targeting = Targeting.viewProductId(productIDTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }

    func getProductID_startWith() throws -> ConfigResponse {
        let productIDTargeting = ProductIDTargeting(kind: .startsWith, value: "oot")
        let targeting = Targeting.viewProductId(productIDTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }

    func getProductID_endWith() throws -> ConfigResponse {
        let productIDTargeting = ProductIDTargeting(kind: .endsWith, value: "ots")
        let targeting = Targeting.viewProductId(productIDTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }

    func getProductSegment_Positive() throws -> ConfigResponse {
        let productSegmentTargeting = ProductSegmentTargeting(kind: .positive,
                                                         segmentationInternalId: "1",
                                                         segmentationExternalId: "2",
                                                         segmentExternalId: "3")
        let targeting = Targeting.viewProductSegment(productSegmentTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }

    func getProductSegment_Negative() throws -> ConfigResponse {
        let productSegmentTargeting = ProductSegmentTargeting(kind: .negative,
                                                         segmentationInternalId: "1",
                                                         segmentationExternalId: "2",
                                                         segmentExternalId: "3")
        let targeting = Targeting.viewProductSegment(productSegmentTargeting)
        return try createConfigResponse(targeting: targeting, operationType: .viewProduct)
    }
}

extension InAppConfigStub {

    enum OperationType: String {
        case viewProduct
        case viewCategory
    }

    func createConfigResponse(targeting: Targeting, operationType: OperationType) throws -> ConfigResponse {
        let settings = Settings(
            operations: .init(
                viewProduct: operationType == .viewProduct ? .init(systemName: operationType.rawValue) : nil,
                viewCategory: operationType == .viewCategory ? .init(systemName: operationType.rawValue) : nil,
                setCart: nil
            ),
            ttl: nil
        )
        return ConfigResponse(
            inapps: FailableDecodableArray(elements: try getInappDTO(with: targeting)),
            monitoring: nil,
            settings: settings,
            abtests: nil
        )
    }

    private func getInappDTO(with targeting: Targeting) throws -> [InAppDTO] {
        return [InAppDTO(id: "1",
                         sdkVersion: .init(min: 8, max: nil),
                         frequency: .once(.init(kind: .session)),
                         targeting: targeting,
                         form: try getForm())]
    }

    private func getForm() throws -> InAppFormDTO {
        let jsonString = """
        {
          "variants": [
            {
              "content": {
                "background": {
                  "layers": [
                    {
                      "action": {
                        "intentPayload": "",
                        "value": "",
                        "$type": "redirectUrl"
                      },
                      "source": {
                        "value": "https://google.png",
                        "$type": "url"
                      },
                      "$type": "image"
                    }
                  ]
                },
                "position": {
                  "margin": {
                    "kind": "dp",
                    "top": 0.0,
                    "right": 20.0,
                    "left": 20.0,
                    "bottom": 0.0
                  },
                  "gravity": {
                    "horizontal": "center",
                    "vertical": "top"
                  }
                },
                "elements": []
              },
              "imageUrl": "",
              "redirectUrl": "",
              "intentPayload": "",
              "$type": "snackbar"
            }
          ]
        }
        """

        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("Не удалось преобразовать строку JSON в Data")
        }

        let decoder = JSONDecoder()
        let formDTO = try decoder.decode(InAppFormDTO.self, from: jsonData)
        return formDTO
    }
}
