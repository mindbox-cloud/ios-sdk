//
//  SettingsModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct Settings: Decodable, Equatable {
    let operations: SettingsOperations?
    let ttl: TimeToLive?
    let slidingExpiration: SlidingExpiration?

    enum CodingKeys: CodingKey {
        case operations, ttl, slidingExpiration
    }
}

extension Settings {
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.operations = try? container.decodeIfPresent(SettingsOperations.self, forKey: .operations)
        self.ttl = try? container.decodeIfPresent(TimeToLive.self, forKey: .ttl)
        self.slidingExpiration = try? container.decodeIfPresent(SlidingExpiration.self, forKey: .slidingExpiration)
    }
}
