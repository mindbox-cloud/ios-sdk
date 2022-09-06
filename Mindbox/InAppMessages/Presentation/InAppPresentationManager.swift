//
//  InAppPresentationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class InAppPresentationManager {

    public init(imagesStorage: InAppImagesStorage) {
        self.imagesStorage = imagesStorage
    }

    private let imagesStorage: InAppImagesStorage

    func present(inAppMessage: InAppMessage) {
        // load image or fetch from cache
        // imagesStorage.getImage()

        // present message logic here
    }
}
