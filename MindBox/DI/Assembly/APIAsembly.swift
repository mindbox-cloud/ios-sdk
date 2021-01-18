//
//  APIAsembly.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

//public struct APIAsembly: Assembly {
//
//    public init() {}

//    public func assemble(container: Swinject.Container) {
//        let baseURL = "https://api.binance.com/api/v3"
//        container
//            .register(ServiceManager.self) { r in
//                return NetworkManagerProvider(baseURL: baseURL)
//            }
//            .inObjectScope(.container)
//        container
//            .register(Services.self) { r in
//                return ServicesProvider(serviceManager: r~>)
//            }
//            .inObjectScope(.container)
//    }
//
//}
