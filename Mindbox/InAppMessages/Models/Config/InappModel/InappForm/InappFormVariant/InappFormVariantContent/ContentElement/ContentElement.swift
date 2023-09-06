//
//  ContentElement.swift
//  Mindbox
//
//  Created by vailence on 04.08.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol ContentElementProtocol: Decodable, Equatable { }

enum ContentElementType: String, Decodable {
    case closeButton
    case unknown
    
    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = ContentElementType(rawValue: type) ?? .unknown
    }
}

enum ContentElementDTO: Decodable, Hashable, Equatable {
    case closeButton(CloseButtonElementDTO)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentElementDTO, rhs: ContentElementDTO) -> Bool {
        switch (lhs, rhs) {
            case (.closeButton, .closeButton): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .closeButton: hasher.combine("closeButton")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentElementDTO.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentElementType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The variant type could not be decoded. The variant will be ignored.")
        }
        
        let elementContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .closeButton:
                let closeButtonElement = try elementContainer.decode(CloseButtonElementDTO.self)
                self = .closeButton(closeButtonElement)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentElementDTO {
    var elementType: ContentElementType {
        switch self {
            case .closeButton:
                return .closeButton
            case .unknown:
                return .unknown
        }
    }
}

enum ContentElement: Decodable, Hashable, Equatable {
    case closeButton(CloseButtonElement)
    case unknown
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }
    
    static func == (lhs: ContentElement, rhs: ContentElement) -> Bool {
        switch (lhs, rhs) {
            case (.closeButton, .closeButton): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
            case .closeButton: hasher.combine("closeButton")
            case .unknown: hasher.combine("unknown")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<ContentElement.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(ContentElementType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The variant type could not be decoded. The variant will be ignored.")
        }
        
        let elementContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()
        
        switch type {
            case .closeButton:
                let closeButtonElement = try elementContainer.decode(CloseButtonElement.self)
                self = .closeButton(closeButtonElement)
            case .unknown:
                self = .unknown
        }
    }
}

extension ContentElement {
    var elementType: ContentElementType {
        switch self {
            case .closeButton:
                return .closeButton
            case .unknown:
                return .unknown
        }
    }
}

extension ContentElement {
    init(type: ContentElementType, closeButton: CloseButtonElement? = nil) throws {
        switch type {
        case .closeButton:
            guard let closeButtonModel = closeButton else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
            self = .closeButton(closeButtonModel)
        case .unknown:
            self = .unknown
        }
    }
}
