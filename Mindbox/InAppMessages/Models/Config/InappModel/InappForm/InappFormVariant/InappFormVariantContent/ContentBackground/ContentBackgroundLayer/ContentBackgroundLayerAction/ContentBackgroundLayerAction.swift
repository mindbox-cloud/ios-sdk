//
//  ContentBackgroundLayerAction.swift
//  Mindbox
//
//  Created by vailence on 03.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ContentBackgroundLayerActionProtocol: Decodable, Equatable { }

// MARK: - DTO
enum ContentBackgroundLayerActionType: String, Decodable {
    case pushPermission
    case redirectUrl
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = ContentBackgroundLayerActionType(rawValue: type) ?? .unknown
    }
}

enum ContentBackgroundLayerActionDTO: Decodable, Hashable, Equatable {
    case pushPermission(PushPermissionLayerActionDTO)
    case redirectUrl(RedirectUrlLayerActionDTO)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentBackgroundLayerActionDTO, rhs: ContentBackgroundLayerActionDTO) -> Bool {
        switch (lhs, rhs) {
            case (.pushPermission, .pushPermission): return true
            case (.redirectUrl, .redirectUrl): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .pushPermission: hasher.combine("pushPermission")
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
            case .pushPermission:
                let pushPermissionAction = try actionContainer.decode(PushPermissionLayerActionDTO.self)
                self = .pushPermission(pushPermissionAction)
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
            case .pushPermission:
                return .pushPermission
            case .redirectUrl:
                return .redirectUrl
            case .unknown:
                return .unknown
        }
    }
}


// MARK: - Real model
enum ContentBackgroundLayerAction: Decodable, Hashable, Equatable {
    case pushPermission(PushPermissionLayerAction)
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
            case .pushPermission: hasher.combine("pushPermission")
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
            case .pushPermission:
                let pushPermissionAction = try actionContainer.decode(PushPermissionLayerAction.self)
                self = .pushPermission(pushPermissionAction)
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
            case .pushPermission:
                return .pushPermission
            case .redirectUrl:
                return .redirectUrl
            case .unknown:
                return .unknown
        }
    }
}

extension ContentBackgroundLayerAction {
    init(type: ContentBackgroundLayerActionType, redirectModel: RedirectUrlLayerAction? = nil, pushPermissionModel: PushPermissionLayerAction? = nil) throws {
        switch type {
            case .pushPermission:
                guard let pushPermissionModel = pushPermissionModel else {
                    throw CustomDecodingError.unknownType("PushPermissionModel type could not be decoded. The variant will be ignored.")
                }
                self = .pushPermission(pushPermissionModel)
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
