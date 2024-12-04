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

enum ContentBackgroundLayerDTO: Decodable, Hashable, Equatable {
    case image(ImageContentBackgroundLayerDTO)
    case unknown

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    static func == (lhs: ContentBackgroundLayerDTO, rhs: ContentBackgroundLayerDTO) -> Bool {
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
        let container: KeyedDecodingContainer<ContentBackgroundLayerDTO.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The layer type could not be decoded. The layer will be ignored.")
        }

        let layerContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .image:
                let imageLayer = try layerContainer.decode(ImageContentBackgroundLayerDTO.self)
                self = .image(imageLayer)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayerDTO {
    var layerType: ContentBackgroundLayerType {
        switch self {
            case .image:
                return .image
            case .unknown:
                return .unknown
        }
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
            throw CustomDecodingError.decodingError("The layer type could not be decoded. The layer will be ignored.")
        }

        let layerContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .image:
                let imageLayer = try layerContainer.decode(ImageContentBackgroundLayer.self)
                self = .image(imageLayer)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayer {
    var layerType: ContentBackgroundLayerType {
        switch self {
            case .image:
                return .image
            case .unknown:
                return .unknown
        }
    }
}

extension ContentBackgroundLayer {
    init(type: ContentBackgroundLayerType, imageLayer: ImageContentBackgroundLayer? = nil) throws {
        switch type {
        case .image:
            guard let imageLayer = imageLayer else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
                self = .image(imageLayer)
        case .unknown:
            self = .unknown
        }
    }
}
