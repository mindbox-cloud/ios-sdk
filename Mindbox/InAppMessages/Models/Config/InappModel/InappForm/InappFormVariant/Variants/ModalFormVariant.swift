//
//  ModalFormVariant.swift
//  FirebaseCore
//
//  Created by vailence on 10.08.2023.
//

import Foundation

struct ModalFormVariantDTO: iFormVariant, Decodable, Equatable {
    let content: InappFormVariantContentDTO?
}

struct ModalFormVariant: iFormVariant, Decodable, Equatable {
    let content: InappFormVariantContent
}
