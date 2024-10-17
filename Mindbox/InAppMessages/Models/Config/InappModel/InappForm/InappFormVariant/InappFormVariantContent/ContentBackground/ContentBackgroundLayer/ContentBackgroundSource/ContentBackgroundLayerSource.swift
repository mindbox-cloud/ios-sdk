//
//  ContentBackgroundLayerSource.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ContentBackgroundLayerSourceProtocol: Decodable, Equatable { }

enum ContentBackgroundLayerSourceType: String, Decodable {
    case url
    case unknown

    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = ContentBackgroundLayerSourceType(rawValue: type) ?? .unknown
    }
}

enum ContentBackgroundLayerSourceDTO: Decodable, Hashable, Equatable {
    case url(UrlLayerSourceDTO)
    case unknown

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    static func == (lhs: ContentBackgroundLayerSourceDTO, rhs: ContentBackgroundLayerSourceDTO) -> Bool {
        switch (lhs, rhs) {
            case (.url, .url): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case .url: hasher.combine("url")
            case .unknown: hasher.combine("unknown")
        }
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentBackgroundLayerSourceDTO.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerSourceType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The source type could not be decoded. The source will be ignored.")
        }

        let sourceContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .url:
                let urlSource = try sourceContainer.decode(UrlLayerSourceDTO.self)
                self = .url(urlSource)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayerSourceDTO {
    var sourceType: ContentBackgroundLayerSourceType {
        switch self {
            case .url:
                return .url
            case .unknown:
                return .unknown
        }
    }
}

enum ContentBackgroundLayerSource: Decodable, Hashable, Equatable {
    case url(UrlLayerSource)
    case unknown

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    static func == (lhs: ContentBackgroundLayerSource, rhs: ContentBackgroundLayerSource) -> Bool {
        switch (lhs, rhs) {
            case (.url, .url): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case .url: hasher.combine("url")
            case .unknown: hasher.combine("unknown")
        }
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentBackgroundLayerSource.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerSourceType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The source type could not be decoded. The source will be ignored.")
        }

        let sourceContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .url:
                let urlSource = try sourceContainer.decode(UrlLayerSource.self)
                self = .url(urlSource)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayerSource {
    var sourceType: ContentBackgroundLayerSourceType {
        switch self {
            case .url:
                return .url
            case .unknown:
                return .unknown
        }
    }
}

extension ContentBackgroundLayerSource {
    init(type: ContentBackgroundLayerSourceType, urlModel: UrlLayerSource? = nil) throws {
        switch type {
        case .url:
            guard let urlModel = urlModel else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
            self = .url(urlModel)
        case .unknown:
            self = .unknown
        }
    }
}
