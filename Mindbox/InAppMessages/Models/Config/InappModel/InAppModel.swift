//
//  InAppModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct InAppDTO: Decodable, Equatable {
    let id: String
    let isPriority: Bool
    let sdkVersion: SdkVersion
    var frequency: InappFrequency?
    let targeting: Targeting
    let form: InAppFormDTO

    enum CodingKeys: CodingKey {
        case id
        case isPriority
        case sdkVersion
        case frequency
        case targeting
        case form
    }
}

extension InAppDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.isPriority = try container.decodeIfPresent(Bool.self, forKey: .isPriority) ?? false
        self.sdkVersion = try container.decode(SdkVersion.self, forKey: .sdkVersion)
        self.frequency = try container.decodeIfPresent(InappFrequency.self, forKey: .frequency)

        if frequency == .unknown {
            throw CustomDecodingError.unknownType("Frequency has unknown type. Inapp will be ignored.")
        }

        if frequency == nil {
            frequency = .once(OnceFrequency(kind: .lifetime))
        }

        self.targeting = try container.decode(Targeting.self, forKey: .targeting)
        self.form = try container.decode(InAppFormDTO.self, forKey: .form)
    }
}

struct InApp: Decodable, Equatable {
    let id: String
    let isPriority: Bool
    let sdkVersion: SdkVersion
    let targeting: Targeting
    var frequency: InappFrequency?
    let form: InAppForm
}
