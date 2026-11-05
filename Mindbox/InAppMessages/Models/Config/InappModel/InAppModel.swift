//
//  InAppModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct InAppDTO: Decodable, Equatable {
    let id: String
    let isPriority: Bool
    let delayTime: String?
    let sdkVersion: SdkVersion
    var frequency: InappFrequency?
    let displayConditions: DisplayConditions
    let targeting: Targeting
    let form: InAppFormDTO
    let tags: [String: String]?

    enum CodingKeys: CodingKey {
        case id
        case isPriority
        case delayTime
        case sdkVersion
        case frequency
        case displayConditions
        case targeting
        case form
        case tags
    }
}

extension InAppDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.isPriority = (try? container.decode(Bool.self, forKey: .isPriority)) ?? false
        
        do {
            self.delayTime = try container.decodeIfPresent(String.self, forKey: .delayTime)
            if let delayTime = self.delayTime {
                Logger.common(message: "[DelayTime] In-app with ID '\(self.id)' has delayTime: \(delayTime)", level: .debug, category: .inAppMessages)
            }
        } catch {
            Logger.common(message: "[[DelayTime] Failed to decode delayTime for in-app with ID '\(self.id)'.", level: .error, category: .inAppMessages)
            self.delayTime = nil
        }
        
        self.sdkVersion = try container.decode(SdkVersion.self, forKey: .sdkVersion)
        do {
            self.frequency = try container.decodeIfPresent(InappFrequency.self, forKey: .frequency)
            if frequency == .unknown {
                throw CustomDecodingError.unknownType("frequency has unknown $type")
            }
        } catch {
            Logger.common(message: "[Frequency] In-app with ID '\(self.id)' dropped: \(Self.dropReason(error))",
                          level: .error, category: .inAppMessages)
            throw error
        }

        if frequency == nil {
            frequency = .once(OnceFrequency(kind: .lifetime))
        }

        do {
            self.displayConditions = try container.decodeIfPresent(DisplayConditions.self, forKey: .displayConditions) ?? .unrestricted
        } catch {
            Logger.common(message: "[DisplayConditions] In-app with ID '\(self.id)' dropped: \(Self.dropReason(error))",
                          level: .error, category: .inAppMessages)
            throw error
        }

        self.targeting = try container.decode(Targeting.self, forKey: .targeting)
        self.form = try container.decode(InAppFormDTO.self, forKey: .form)

        self.tags = try? container.decodeIfPresent([String: String].self, forKey: .tags)
    }

    /// Short reason for a log line: the SDK's own message, or the decoder's description of the bad value.
    private static func dropReason(_ error: Error) -> String {
        switch error {
        case CustomDecodingError.decodingError(let message), CustomDecodingError.unknownType(let message):
            return message
        case DecodingError.typeMismatch(_, let context), DecodingError.keyNotFound(_, let context),
             DecodingError.valueNotFound(_, let context), DecodingError.dataCorrupted(let context):
            return context.debugDescription
        default:
            return String(describing: error)
        }
    }
}

struct InApp: Decodable, Equatable {
    let id: String
    let isPriority: Bool
    let delayTime: String?
    let sdkVersion: SdkVersion
    let targeting: Targeting
    var frequency: InappFrequency?
    let displayConditions: DisplayConditions
    let form: InAppForm
    let tags: [String: String]?
}
