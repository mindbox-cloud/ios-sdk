//
//  MBEventRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 03.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class MBEventRepository: EventRepository {
    private let fetcher: NetworkFetcher

    private let persistenceStorage: PersistenceStorage

    init(fetcher: NetworkFetcher, persistenceStorage: PersistenceStorage) {
        self.fetcher = fetcher
        self.persistenceStorage = persistenceStorage
    }

    func send(event: Event, completion: @escaping (Result<Void, MindboxError>) -> Void) {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            completion(.failure(error))
            return
        }
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "DeviceUUID is not set"
            ))
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

    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable {
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            completion(.failure(error))
            return
        }
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "DeviceUUID is not set"
            ))
            completion(.failure(error))
            return
        }
        let wrapper = EventWrapper(
            event: event,
            endpoint: configuration.endpoint,
            deviceUUID: deviceUUID
        )
        let route = makeRoute(wrapper: wrapper)
        fetcher.request(type: type, route: route, needBaseResponse: true, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case let .success(response):
                    completion(.success(response))
                }
            }
        })
    }

    private func makeRoute(wrapper: EventWrapper) -> Route {
        switch wrapper.event.type {
        case .installed,
             .infoUpdated,
             .keepAlive,
             .trackClick,
             .installedWithoutCustomer,
             .inAppViewEvent,
             .inAppClickEvent,
             .inAppTargetingEvent,
             .sdkLogs:
            return EventRoute.asyncEvent(wrapper)
        case .customEvent:
            return EventRoute.customAsyncEvent(wrapper)
        case .trackVisit:
            return EventRoute.trackVisit(wrapper)
        case .syncEvent:
            return EventRoute.syncEvent(wrapper)
        }
    }
    
    /// Cancels all ongoing network requests made via this repository.
    func cancelAllRequests() {
        fetcher.cancelAllTasks()
    }
}
