//
//  SlidingExpirationModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 04.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct SlidingExpiration: Decodable, Equatable {
        let config: String?
        let pushTokenKeepalive: String?

        enum CodingKeys: CodingKey {
            case config
            case pushTokenKeepalive
        }
    }
}

extension Settings.SlidingExpiration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.config = try? container.decodeIfPresent(String.self, forKey: .config)
        self.pushTokenKeepalive = try? container.decodeIfPresent(String.self, forKey: .pushTokenKeepalive)

        if config == nil && pushTokenKeepalive == nil {
            // Will never be caught because of `try?` in `Settings.init`
            throw DecodingError.dataCorruptedError(forKey: .config, in: container, debugDescription: "The `operation` type could not be decoded because `config` and `pushTokenKeepalive` are nil")
        }
    }
}
