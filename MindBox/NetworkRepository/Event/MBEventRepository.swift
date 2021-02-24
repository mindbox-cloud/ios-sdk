//
//  MBEventRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBEventRepository: EventRepository {
    
    @Injected var fetcher: NetworkFetcher
    
    @Injected var configuration: ConfigurationStorage
    
    func send(event: Event, completion: @escaping (Result<Void, ErrorModel>) -> Void) {
        guard let configuration = configuration.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        guard let deviceUUID = configuration.deviceUUID else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: MindBox.Errors.invalidConfiguration(reason: "DeviceUUID is not set")
            )
            completion(.failure(error))
            return
        }
        let wrapper = EventWrapper(
            event: event,
            endpoint: configuration.endpoint,
            deviceUUID: deviceUUID
        )
        let route = makeRoute(wrapper: wrapper)
        fetcher.request(route: route, completion: completion)
    }
    
    private func makeRoute(wrapper: EventWrapper) -> Route {
        switch wrapper.event.type {
        case .pushDelivered:
             return EventRoute.pushDeleveried(wrapper)
        case .installed,
             .infoUpdated:
            return EventRoute.asyncEvent(wrapper)
        }
    }
    
}
