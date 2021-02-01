//
//  MobileApplication.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

enum MobileApplicationRoute: Route {
    
    case installed(MobileApplicationInstalledDataWrapper),
         infoUpdated
    
    var method: HTTPMethod {
        switch self {
        case .installed,
             .infoUpdated:
            return .post
        }
    }
    
    var path: String {
        switch self {
        case .installed,
             .infoUpdated:
            return "/v3/operations/sync"
        }
    }
    
    var headers: HTTPHeaders? {
        return nil
    }
    
    var queryParameters: QueryParameters {
        switch self {
        case let .installed(wrapper):
            let query = wrapper.query
            return [
                "endpointId": query.endpointId,
                "operation": query.operation,
                "deviceUUID": query.deviceUUID
            ]
        case .infoUpdated:
            return ["sdfsd": "sdfsf"]
        }
    }
    
    var body: Data? {
        switch self {
        case let .installed(wrapper):
            return try? JSONEncoder().encode(wrapper.body)
        case .infoUpdated:
            return nil
        }
    }
    
    
}
