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

        enum CodingKeys: CodingKey {
            case config
        }
    }
}

extension Settings.SlidingExpiration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let config = try? container.decodeIfPresent(String.self, forKey: .config) {
            self.config = config
        } else {
            throw DecodingError.dataCorruptedError(forKey: .config, in: container, debugDescription: "Missing required key 'config'")
        }
    }
}
