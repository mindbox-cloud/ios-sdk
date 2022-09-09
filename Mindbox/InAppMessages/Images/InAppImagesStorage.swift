//
//  InAppImagesStorage.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

/// This class manages images from in-app messages
final class InAppImagesStorage {

    func getImage(url: URL, completionQueue: DispatchQueue, completion: @escaping (Data?) -> Void) {
        downloadImage(url: url, completionQueue: completionQueue, completion: completion)
    }

    private func downloadImage(url: URL, completionQueue: DispatchQueue, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: url) { (data, _, _) in
            guard let data = data else {
                completionQueue.async { completion(nil) }
                return
            }
            completionQueue.async { completion(data) }
        }
        .resume()
    }
}
