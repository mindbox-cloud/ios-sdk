//
//  InappConfigurationTests.swift
//  MindboxTests
//
//  Created by vailence on 28.11.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

fileprivate enum InappConfig: String, Configurable {
    typealias DecodeType = ConfigResponse

    case configWithTwoInapps = "InAppConfiguration"
}

@Suite("Inapp Mapper Tests")
class InappConfigurationTests {

    private var mapper: InappMapperProtocol

    init() {
        TestConfiguration.configure()
        self.mapper = DI.injectOrFail(InappMapperProtocol.self)
    }

    @available(iOS 13.0, *)
    @Test("Первый инапп не подходит по версии SDK.", .tags(.sdkVersion))
    func first_inapp_doesnt_fit_sdk_return_second() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 9
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "2")
    }

    @available(iOS 13.0, *)
    @Test("Оба инаппа подходят по версии SDK.", .tags(.sdkVersion))
    func first_inapp_fit_sdk_return_first() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 5
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result?.inAppId == "1")
    }

    @available(iOS 13.0, *)
    @Test("Оба инаппа не подходят по версии SDK.", .tags(.sdkVersion))
    func both_inapps_doesnt_fit_sdk_return_nil() async throws {
        let response = try InappConfig.configWithTwoInapps.getConfig()

        let sdkValidator = DI.injectOrFail(SDKVersionValidator.self)
        sdkValidator.sdkVersionNumeric = 1
        let result = await withCheckedContinuation { continuation in
            mapper.handleInapps(nil, response) { formData in
                continuation.resume(returning: formData)
            }
        }

        #expect(result == nil)
    }
}
