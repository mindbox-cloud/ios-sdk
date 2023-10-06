//
//  ContentBackgroundLayerAction.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ContentBackgroundLayerActionProtocol: Decodable, Equatable { }

enum ContentBackgroundLayerActionType: String, Decodable {
    case redirectUrl
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = ContentBackgroundLayerActionType(rawValue: type) ?? .unknown
    }
}

enum ContentBackgroundLayerActionDTO: Decodable, Hashable, Equatable {
    case redirectUrl(RedirectUrlLayerActionDTO)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentBackgroundLayerActionDTO, rhs: ContentBackgroundLayerActionDTO) -> Bool {
        switch (lhs, rhs) {
            case (.redirectUrl, .redirectUrl): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .redirectUrl: hasher.combine("redirectUrl")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentBackgroundLayerActionDTO.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerActionType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The action type could not be decoded. The action will be ignored.")
        }
        
        let actionContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .redirectUrl:
                let redirectUrlAction = try actionContainer.decode(RedirectUrlLayerActionDTO.self)
                self = .redirectUrl(redirectUrlAction)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayerActionDTO {
    var actionType: ContentBackgroundLayerActionType {
        switch self {
            case .redirectUrl:
                return .redirectUrl
            case .unknown:
                return .unknown
        }
    }
}

enum ContentBackgroundLayerAction: Decodable, Hashable, Equatable {
    case redirectUrl(RedirectUrlLayerAction)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentBackgroundLayerAction, rhs: ContentBackgroundLayerAction) -> Bool {
        switch (lhs, rhs) {
            case (.redirectUrl, .redirectUrl): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .redirectUrl: hasher.combine("redirectUrl")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentBackgroundLayerAction.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentBackgroundLayerActionType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The action type could not be decoded. The action will be ignored.")
        }
        
        let actionContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .redirectUrl:
                let redirectUrlAction = try actionContainer.decode(RedirectUrlLayerAction.self)
                self = .redirectUrl(redirectUrlAction)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentBackgroundLayerAction {
    var actionType: ContentBackgroundLayerActionType {
        switch self {
            case .redirectUrl:
                return .redirectUrl
            case .unknown:
                return .unknown
        }
    }
}

extension ContentBackgroundLayerAction {
    init(type: ContentBackgroundLayerActionType, redirectModel: RedirectUrlLayerAction? = nil) throws {
        switch type {
            case .redirectUrl:
                guard let redirectModel = redirectModel else {
                    throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
                }
                self = .redirectUrl(redirectModel)
            case .unknown:
                self = .unknown
        }
    }
}
