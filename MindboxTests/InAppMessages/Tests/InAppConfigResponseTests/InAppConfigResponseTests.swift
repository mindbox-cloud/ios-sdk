//
//  InAppConfigResponseTests.swift
//  MindboxTests
//
//  Created by Максим Казаков on 12.10.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

class InAppConfigResponseTests: XCTestCase {

    func test_2InApps_oneFitsInAppsSdkVersion_andOneDoesnt() throws {
        let response = try getConfigWithTwoInapps()
        let config = InAppConfigutationMapper(inAppsVersion: 1)
            .mapConfigResponse(response)
        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(
                    id: "b90480f3-dc9f-40f9-8ad1-09d08ef51ab6",
                    targeting: .init(
                        segmentation: "74f45d0a-6f1e-4e77-bd9f-eefe9f4b43b0",
                        segment: "42646a9f-6330-4aa7-ab36-00447b7850cf"
                    ),
                    formDataVariants: [
                        .init(
                            imageUrl: "https://cs.pikabu.ru/post_img/big/2013/12/31/9/1388645055_1336973337.jpg",
                            redirectUrl: "",
                            intentPayload: ""
                        )
                    ]
                )
            ]
        ])
        XCTAssertEqual(expected, config)
    }

    func test_2InApps_bothFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        let config = InAppConfigutationMapper(inAppsVersion: 2)
            .mapConfigResponse(response)
        let expected = InAppConfig(inAppsByEvent: [
            .start: [
                .init(
                    id: "b90480f3-dc9f-40f9-8ad1-09d08ef51ab6",
                    targeting: .init(
                        segmentation: "74f45d0a-6f1e-4e77-bd9f-eefe9f4b43b0",
                        segment: "42646a9f-6330-4aa7-ab36-00447b7850cf"
                    ),
                    formDataVariants: [
                        .init(
                            imageUrl: "https://cs.pikabu.ru/post_img/big/2013/12/31/9/1388645055_1336973337.jpg",
                            redirectUrl: "",
                            intentPayload: ""
                        )
                    ]
                ),
                .init(
                    id: "d6d78e93-2994-4ffe-a85e-886b1a5df0cd",
                    targeting: .init(
                        segmentation: "6b5629d5-b1eb-497f-b03c-1c71a49f36c2",
                        segment: "424136a9-2b33-49f3-bdf3-d363905448eb"
                    ),
                    formDataVariants: [
                        .init(
                            imageUrl: "https://cs.pikabu.ru/post_img/big/2013/12/31/9/1388645055_1336973337.jpg",
                            redirectUrl: "",
                            intentPayload: ""
                        )
                    ]
                )
            ]
        ])
        XCTAssertEqual(expected, config)
    }

    func test_invalisInApps() throws {
        let response = try getConfigWithInvalidInapps()
        let config = InAppConfigutationMapper(inAppsVersion: 2).mapConfigResponse(response)
        XCTAssertEqual(1, config.inAppsByEvent.count)
        let inappsForStartEvent = config.inAppsByEvent[.start]!
        XCTAssertEqual(1, inappsForStartEvent.count)
        let onlyValidInapp = inappsForStartEvent.first!
        XCTAssertEqual(onlyValidInapp.id, "00000000-0000-0000-0000-000000000002")
    }

    func test_2InApps_bothDontFitInAppsSdkVersion() throws {
        let response = try getConfigWithTwoInapps()
        let config = InAppConfigutationMapper(inAppsVersion: 0)
            .mapConfigResponse(response)
        let expected = InAppConfig(inAppsByEvent: [:])
        XCTAssertEqual(expected, config)
    }

    private func getConfigWithTwoInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfiguration", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }

    private func getConfigWithInvalidInapps() throws -> InAppConfigResponse {
        let bundle = Bundle(for: InAppConfigResponseTests.self)
        let fileURL = bundle.url(forResource: "InAppConfigurationInvalid", withExtension: "json")!
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(InAppConfigResponse.self, from: data)
    }
}
