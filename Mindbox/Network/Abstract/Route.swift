//
//  Route.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 01.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol Route {
            
    var method: HTTPMethod { get }
    
    var path: String { get }
    
    var headers: HTTPHeaders? { get }
    
    var queryParameters: QueryParameters { get }
    
    var body: Data? { get }
    
}
