//
//  NetworkService.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class NetworkService {
    private let session: URLSession
    private let configuration: MBConfiguration

    init(utilitiesFetcher: MBUtilitiesFetcher, configuration: MBConfiguration) {
        let sessionConfiguration: URLSessionConfiguration = .default
        let sdkVersion = utilitiesFetcher.sdkVersion ?? "unknow"
        let appVersion = utilitiesFetcher.appVerson ?? "unknow"
        let appName = utilitiesFetcher.hostApplicationName ?? "unknow"
        let userAgent: String = "mindbox.sdk/\(sdkVersion) (\(DeviceModelHelper.os) \(DeviceModelHelper.iOSVersion); \(DeviceModelHelper.model)) \(appName)/\(appVersion)"
        sessionConfiguration.httpAdditionalHeaders = [
            "Mindbox-Integration": "iOS-SDK",
            "Mindbox-Integration-Version": sdkVersion,
            "User-Agent": userAgent,
            "Content-Type": "application/json; charset=utf-8",
        ]
        session = URLSession(configuration: sessionConfiguration)
        self.configuration = configuration
    }

    public func sendPushDelivered(event: Event, completion: @escaping ((Bool) -> Void)) {
        guard let deviceUUID = configuration.previousDeviceUUID else {
            completion(false)
            return
        }

        let wrapper = EventWrapper(
            event: event,
            endpoint: configuration.endpoint,
            deviceUUID: deviceUUID
        )

        let builder = URLRequestBuilder(domain: configuration.domain)
        do {
            let urlRequest = try builder.asURLRequest(route: PushDeliveredEventRoute(wrapper: wrapper))

            Logger.network(request: urlRequest, httpAdditionalHeaders: session.configuration.httpAdditionalHeaders)
            
            session.dataTask(with: urlRequest) { data, response, error in
                Logger.response(data: data, response: response, error: error)
                if let error = error {
                    let errorModel = MindboxError.unknown(error)
                    Logger.error(errorModel)
                    completion(false)
                }

                if let response = response as? HTTPURLResponse {
                    if (200 ... 399).contains(response.statusCode) {
                        Logger.common(message: "Push delivered", level: .info, category: .network)
                        completion(true)
                    } else {
                        let errorModel = MindboxError.invalidResponse(response)
                        Logger.error(errorModel)
                        completion(false)
                    }
                } else {
                    let errorModel = MindboxError.invalidResponse(response)
                    Logger.error(errorModel)
                    completion(false)
                }
            }.resume()
        } catch let error {
            let errorModel = MindboxError.unknown(error)
            Logger.error(errorModel)
            completion(false)
        }
    }
}
