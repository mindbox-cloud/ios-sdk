//
//  InappFrequency.swift
//  Mindbox
//
//  Created by vailence on 10.04.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol iInappFrequency: Decodable, Equatable { }

enum InappFrequencyType: String, Decodable {
    case periodic
    case once
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = InappFrequencyType(rawValue: type) ?? .unknown
    }
}

enum InappFrequency: Decodable, Equatable, Hashable {
    case periodic(PeriodicFrequency)
    case once(OnceFrequency)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: InappFrequency, rhs: InappFrequency) -> Bool {
        switch (lhs, rhs) {
            case (.periodic, .periodic): return true
            case (.once, .once): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .periodic: hasher.combine("periodic")
            case .once: hasher.combine("once")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<InappFrequency.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(InappFrequencyType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The variant type could not be decoded. The variant will be ignored.")
        }
        
        let variantContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .periodic:
                let periodicFrequency = try variantContainer.decode(PeriodicFrequency.self)
                self = .periodic(periodicFrequency)
            case .once:
                let onceFrequency = try variantContainer.decode(OnceFrequency.self)
                self = .once(onceFrequency)
            case .unknown:
                self = .unknown
        }
    }
}
