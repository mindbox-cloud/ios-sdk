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
    case snackbar
    case webview
    case unknown

    init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
        let type: String = try container.decode(String.self)
        self = MindboxFormVariantType(rawValue: type) ?? .unknown
    }
}

enum MindboxFormVariantDTO: Decodable, Hashable, Equatable {
    case modal(ModalFormVariantDTO)
    case snackbar(SnackbarFormVariantDTO)
    case webview(WebviewFormVariantDTO)
    case unknown

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    static func == (lhs: MindboxFormVariantDTO, rhs: MindboxFormVariantDTO) -> Bool {
        switch (lhs, rhs) {
            case (.modal, .modal): return true
            case (.snackbar, .snackbar): return true
            case (.webview, .webview): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case .modal: hasher.combine("modal")
            case .snackbar: hasher.combine("snackbar")
            case .webview: hasher.combine("webview")
            case .unknown: hasher.combine("unknown")
        }
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<MindboxFormVariantDTO.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(MindboxFormVariantType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The variant type could not be decoded. The variant will be ignored.")
        }

        let variantContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .modal:
                let modalVariant = try variantContainer.decode(ModalFormVariantDTO.self)
                self = .modal(modalVariant)
            case .snackbar:
                let snackbarVariant = try variantContainer.decode(SnackbarFormVariantDTO.self)
                self = .snackbar(snackbarVariant)
            case .webview:
                let webviewVariant = try variantContainer.decode(WebviewFormVariantDTO.self)
                self = .webview(webviewVariant)
            case .unknown:
                self = .unknown
        }
    }
}

enum MindboxFormVariant: Decodable, Hashable, Equatable {
    case modal(ModalFormVariant)
    case snackbar(SnackbarFormVariant)
    case webview(WebviewFormVariant)
    case unknown

    enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    static func == (lhs: MindboxFormVariant, rhs: MindboxFormVariant) -> Bool {
        switch (lhs, rhs) {
            case (.modal, .modal): return true
            case (.snackbar, .snackbar): return true
            case (.webview, .webview): return true
            case (.unknown, .unknown): return true
            default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
            case .modal: hasher.combine("modal")
            case .snackbar: hasher.combine("snackbar")
            case .webview: hasher.combine("webview")
            case .unknown: hasher.combine("unknown")
        }
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<MindboxFormVariant.CodingKeys> = try decoder.container(
            keyedBy: CodingKeys.self)
        guard let type = try? container.decode(MindboxFormVariantType.self, forKey: .type) else {
            throw CustomDecodingError.decodingError("The variant type could not be decoded. The variant will be ignored.")
        }

        let variantContainer: SingleValueDecodingContainer = try decoder.singleValueContainer()

        switch type {
            case .modal:
                let modalVariant = try variantContainer.decode(ModalFormVariant.self)
                self = .modal(modalVariant)
            case .snackbar:
                let snackbarVariant = try variantContainer.decode(SnackbarFormVariant.self)
                self = .snackbar(snackbarVariant)
            case .webview:
                let webviewVariant = try variantContainer.decode(WebviewFormVariant.self)
                self = .webview(webviewVariant)
            case .unknown:
                self = .unknown
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
        }
    }
}

extension MindboxFormVariant {
    init(type: MindboxFormVariantType,
         modalVariant: ModalFormVariant? = nil,
         snackbarVariant: SnackbarFormVariant? = nil,
         webviewVariant: WebviewFormVariant? = nil
    ) throws {
        switch type {
        case .modal:
            guard let modalVariant = modalVariant else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
            self = .modal(modalVariant)

        case .snackbar:
            guard let snackbarVariant = snackbarVariant else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
            self = .snackbar(snackbarVariant)
            
        case .webview:
            guard let webviewVariant = webviewVariant else {
                throw CustomDecodingError.unknownType("The variant type could not be decoded. The variant will be ignored.")
            }
            self = .webview(webviewVariant)

        case .unknown:
            self = .unknown
        }
    }
}
