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
        let inappSession: String?

        enum CodingKeys: CodingKey {
            case inappSession
        }
    }
}

extension Settings.SlidingExpiration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let inappSession = try? container.decodeIfPresent(String.self, forKey: .inappSession) {
            self.inappSession = inappSession
        } else {
            throw DecodingError.dataCorruptedError(forKey: .inappSession, in: container, debugDescription: "Missing required key 'inappSession'")
        }
    }
}
