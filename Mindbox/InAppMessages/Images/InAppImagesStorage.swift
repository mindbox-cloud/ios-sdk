//
//  ImageDownloader.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

protocol ImageDownloader {
    func downloadImage(withUrl imageUrl: String, completion: @escaping (URL?, HTTPURLResponse?, Error?) -> Void)
    func cancel()
}

class URLSessionImageDownloader: ImageDownloader {
    
    private let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    private var task: URLSessionDownloadTask?
    
    func downloadImage(withUrl imageUrl: String, completion: @escaping (URL?, HTTPURLResponse?, Error?) -> Void) {
        guard let url = URL(string: imageUrl) else {
            completion(nil, nil, NSError(domain: "Invalid URL", code: -1, userInfo: nil))
            return
        }
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = persistenceStorage.imageLoadingMaxTimeInSeconds ?? 3
        let session = URLSession(configuration: configuration)

        let downloadTask = session.downloadTask(with: url) { (localURL, response, error) in
            completion(localURL, response as? HTTPURLResponse, error)
        }
        
        task = downloadTask
        downloadTask.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
}
