//
//  TimeToLiveModel.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/12/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct TimeToLive: Decodable, Equatable {
        let inapps: String?
        
        enum CodingKeys: CodingKey {
            case inapps
        }
    }
}

extension Settings.TimeToLive {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let inapps = try? container.decodeIfPresent(String.self, forKey: .inapps) {
            self.inapps = inapps
        } else {
            throw DecodingError.dataCorruptedError(forKey: .inapps, in: container, debugDescription: "Missing required key 'inapps'")
        }
    }
}
