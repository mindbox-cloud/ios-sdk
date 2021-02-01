//
//  NetworkConfigurationType.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol NetworkConfiguration {
    
    var baseURL: URL { get }
    
    var cachePolicy: URLRequest.CachePolicy { get }
    
    var timeoutInterval: TimeInterval { get }
    
    var additionalHeaders: HTTPHeaders? { get }
    
}
