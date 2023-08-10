//
//  ContentBackgroundLayer.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ContentBackgroundLayerProtocol: Decodable, Equatable { }

enum ContentBackgroundLayerType: String, Decodable {
    case image
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = ContentBackgroundLayerType(rawValue: type) ?? .unknown
    }
}

enum ContentBackgroundLayer: Decodable, Hashable, Equatable {
    case image(ImageContentBackgroundLayer)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentBackgroundLayer, rhs: ContentBackgroundLayer) -> Bool {
        switch (lhs, rhs) {
            case (.image, .image): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .image: hasher.combine("image")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentBackgroundLayer.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerType.self, forKey: .type) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Form variant is unknown. Ignored."
            )
        }
        
        let layerContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .image:
                let imageLayer = try layerContainer.decode(ImageContentBackgroundLayer.self)
                self = .image(imageLayer)
            case .unknown:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Form variant is unknown. Ignored."
                )
        }
    }
}
