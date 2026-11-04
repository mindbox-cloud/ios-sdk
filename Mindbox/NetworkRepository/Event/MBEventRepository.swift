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
    private let trackingIdsResolver: TrackingIdsResolver
    private let trackingHostResolver: TrackingHostResolver

    init(fetcher: NetworkFetcher,
         persistenceStorage: PersistenceStorage,
         trackingIdsResolver: TrackingIdsResolver,
         trackingHostResolver: TrackingHostResolver) {
        self.fetcher = fetcher
        self.persistenceStorage = persistenceStorage
        self.trackingIdsResolver = trackingIdsResolver
        self.trackingHostResolver = trackingHostResolver
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
        let route = EventRoute(EventWrapper(event: event, endpoint: configuration.endpoint, deviceUUID: deviceUUID))
        let firstSend = trackingIdsResolver.takeFirstSend(of: event)
        guard let attachment = event.isRetry ? nil : trackingIdsResolver.attachment(for: event.type, trackingHost: trackingHostResolver.trackingHost),
              case let .sdkOperation(operation) = event.type.request else {
            fetcher.request(route: route, completion: completion)
            return
        }
        let idsRoute = EventRoute(EventWrapper(event: event, endpoint: configuration.endpoint, deviceUUID: deviceUUID, trackingIds: attachment))
        let instanceId = persistenceStorage.applicationInstanceId
        fetcher.request(type: BaseResponse.self, route: idsRoute) { [fetcher, persistenceStorage, trackingIdsResolver] result in
            switch result {
            case .success:
                let hash = attachment.hash
                if let firstSend, trackingIdsResolver.accept(hash, from: firstSend, instanceId: instanceId, in: persistenceStorage) {
                    Logger.common(
                        message: "[TrackingIds] " + attachment.sentLogMessage(operation: operation),
                        level: .debug,
                        category: .general
                    )
                }
                completion(.success(()))
            case let .failure(error) where event.type == .keepAlive:
                Logger.common(
                    message: "[TrackingIds] Keepalive did not reach the tracking host (\(error.localizedDescription)), retrying on the main host without ids",
                    level: .info,
                    category: .general
                )
                fetcher.request(route: route, completion: completion)
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func send<T>(type: T.Type, event: Event, completion: @escaping (Result<T, MindboxError>) -> Void) where T: Decodable {
        let deliver: (Result<T, MindboxError>) -> Void = { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
        guard let configuration = persistenceStorage.configuration else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Configuration is not set"
            ))
            deliver(.failure(error))
            return
        }
        guard let deviceUUID = persistenceStorage.deviceUUID else {
            let error = MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "DeviceUUID is not set"
            ))
            deliver(.failure(error))
            return
        }
        let wrapper = EventWrapper(
            event: event,
            endpoint: configuration.endpoint,
            deviceUUID: deviceUUID
        )
        let route = EventRoute(wrapper)
        fetcher.request(type: type, route: route, completion: deliver)
    }

    func sendRaw(event: Event, completion: @escaping (Result<Data, MindboxError>) -> Void) {
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
        let route = EventRoute(wrapper)
        fetcher.requestRaw(route: route) { result in
            DispatchQueue.main.async {
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case let .success(data):
                    completion(.success(data))
                }
            }
        }
    }

    func cancelAllRequests() {
        fetcher.cancelAllTasks()
    }
}
