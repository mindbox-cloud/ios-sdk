//
//  FeatureTogglesModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct FeatureToggles: Decodable, Equatable {
        let shouldSendInAppShowError: Bool?

        enum CodingKeys: String, CodingKey {
            case shouldSendInAppShowError = "MobileSdkShouldSendInAppShowError"
        }
    }
}

extension Settings.FeatureToggles {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.shouldSendInAppShowError = try? container.decodeIfPresent(Bool.self, forKey: .shouldSendInAppShowError)
    }
}
