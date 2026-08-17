//
//  ViewFactoryProtocol.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import Foundation

struct ViewFactoryParameters {
    let model: MindboxFormVariant
    let id: String
    let imagesDict: [String: UIImage]
    let firstImageValue: String
    let onPresented: () -> Void
    let onTapAction: InAppMessageTapAction
    let onClose: () -> Void
    let onError: (InAppPresentationError) -> Void
    let operation: (name: String, body: String)?
    let tags: [String: String]?

    /// See ``InAppFormData/extraParams``. Only a web page can use them, so only the web factory reads
    /// this.
    let extraParams: [String: JSONValue]?
}

protocol ViewFactoryProtocol {
    func create(with params: ViewFactoryParameters) -> UIViewController?
}
