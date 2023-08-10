//
//  iFormVariant.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol iFormVariant: Decodable, Equatable { }

enum MindboxFormVariantType: String, Decodable {
    case modal
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = MindboxFormVariantType(rawValue: type) ?? .unknown
    }
}

enum MindboxFormVariant: Decodable, Hashable, Equatable {
    case modal(ModalFormVariant)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: MindboxFormVariant, rhs: MindboxFormVariant) -> Bool {
        switch (lhs, rhs) {
            case (.modal, .modal): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .modal: hasher.combine("modal")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<MindboxFormVariant.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(MindboxFormVariantType.self, forKey: .type) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Form variant is unknown. Ignored."
            )
        }
        
        let variantContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .modal:
                let modalVariant = try variantContainer.decode(ModalFormVariant.self)
                self = .modal(modalVariant)
            case .unknown:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Form variant is unknown. Ignored."
                )
        }
    }
}
