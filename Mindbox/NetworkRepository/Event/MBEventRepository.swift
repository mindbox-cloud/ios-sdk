//
//  MBEventRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBEventRepository: EventRepository {
    
    private let fetcher: NetworkFetcher
    
    private let persistenceStorage: PersistenceStorage
    
    init(fetcher: NetworkFetcher, persistenceStorage: PersistenceStorage) {
        self.fetcher = fetcher
        self.persistenceStorage = persistenceStorage
    }
    
    func send(event: Event, completion: @escaping (Result<Void, ErrorModel>) -> Void) {
        guard let configuration = persistenceStorage.configuration else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: Mindbox.Errors.invalidConfiguration(reason: "Configuration is not set")
            )
            completion(.failure(error))
            return
        }
        guard let deviceUUID = configuration.previousDeviceUUID else {
            let error = ErrorModel(
                errorKey: ErrorKey.configuration.rawValue,
                rawError: Mindbox.Errors.invalidConfiguration(reason: "DeviceUUID is not set")
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
             .infoUpdated,
             .trackClick:
            return EventRoute.asyncEvent(wrapper)
        case .customEvent:
            return EventRoute.customAsyncEvent(wrapper)
        case .trackVisit:
            return EventRoute.trackVisit(wrapper)
        }
    }
    
}
