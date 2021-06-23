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

            Logger.log("Request details: \(urlRequest)", type: .debug)
            Logger.log("Request headers: \(urlRequest.allHTTPHeaderFields ?? [:]); \(session.configuration.httpAdditionalHeaders ?? [:])", type: .debug)
            
            session.dataTask(with: urlRequest) { _, response, error in
                if let error = error {
                    Logger.log("An error occured for request \(error)", type: .error)
                    completion(false)
                }

                if let response = response as? HTTPURLResponse {
                    if (200 ... 399).contains(response.statusCode) {
                        Logger.log("Push delivered", type: .info)
                        Logger.log("Response details: \(response)", type: .debug)
                        completion(true)
                    } else {
                        Logger.log("Invalid response. Status code \(response.statusCode)", type: .error)
                        completion(false)
                    }
                } else {
                    Logger.log("Invalid response", type: .error)
                    completion(false)
                }
            }.resume()
        } catch {
            Logger.log("An error occured for request \(error)", type: .error)
            completion(false)
        }
    }
}
