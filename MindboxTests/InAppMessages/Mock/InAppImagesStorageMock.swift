//
//  InAppImagesStorageMock.swift
//  MindboxTests
//
//  Created by Максим Казаков on 14.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppImagesStorageMock: InAppImagesStorageProtocol {
    var imageResult: Data?

    func getImage(url: URL, completionQueue: DispatchQueue, completion: @escaping (Data?) -> Void) {
        completion(imageResult)
    }
}
