//
//  MBEventRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBEventRepository: EventRepository {
    
    private let fetcher: NetworkFetcher
    
    private let configuration: ConfigurationStorage
    
    init(fetcher: NetworkFetcher, configuration: ConfigurationStorage) {
        self.fetcher = fetcher
        self.configuration = configuration
    }
    
    func send(event: Event, completion: @escaping (Result<Void, ErrorModel>) -> Void) {
        guard let configuration = configuration.startConfiguration else {
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
        let route = EventRoute.asyncEvent(wrapper)
        fetcher.request(route: route, completion: completion)
    }
    
}
