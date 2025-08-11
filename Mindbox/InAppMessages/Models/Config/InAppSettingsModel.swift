//
//  InAppSettingsModel.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 04.02.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    struct InAppSettings: Decodable, Equatable {
        let maxInappsPerSession: Int?
        let maxInappsPerDay: Int?
        let minIntervalBetweenShows: String?

        enum CodingKeys: CodingKey {
            case maxInappsPerSession
            case maxInappsPerDay
            case minIntervalBetweenShows
        }
    }
}

extension Settings.InAppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.maxInappsPerSession = try? container.decodeIfPresent(Int.self, forKey: .maxInappsPerSession)
        self.maxInappsPerDay = try? container.decodeIfPresent(Int.self, forKey: .maxInappsPerDay)
        self.minIntervalBetweenShows = try? container.decodeIfPresent(String.self, forKey: .minIntervalBetweenShows)
        
        if maxInappsPerSession == nil && maxInappsPerDay == nil && minIntervalBetweenShows == nil {
            throw DecodingError.dataCorruptedError(forKey: .maxInappsPerSession, in: container, debugDescription: "The `operation` type could not be decoded because all values are nil")
        }
    }
}
