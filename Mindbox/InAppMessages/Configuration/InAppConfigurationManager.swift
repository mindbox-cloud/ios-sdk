//
//  InAppConfigurationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol InAppConfigurationDelegate: AnyObject {
    func didPreparedConfiguration()
}

/// Prepares in-apps configation (loads from network, stores in cache, cache invalidation).
/// Also builds domain models on the base of configuration: in-app requests, in-app message models.
class InAppConfigurationManager {

    private let configUrl = URL(string: "https://web-bucket-inapps-configs-production.storage.yandexcloud.net/byendpoint/someTestMobileEndpoint.json")!
    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.Mindbox.configurationManager")
    private var configuration: InAppConfig!
    private let inAppConfigRepository: InAppConfigurationRepository

    init(inAppConfigRepository: InAppConfigurationRepository) {
        self.inAppConfigRepository = inAppConfigRepository
    }

    weak var delegate: InAppConfigurationDelegate?

    func prepareConfiguration() {
        queue.async {
            if let config = self.fetchConfigFromCache() {
                self.setConfigPrepared(config)
            } else {
                self.downloadConfig()
            }
        }
    }

    func buildInAppRequest(event: InAppMessageTriggerEvent) -> InAppsCheckRequest? {
        queue.sync {
            guard let configuration = configuration,
                  let inAppInfos = configuration.inAppsByEvent[event],
                  !inAppInfos.isEmpty
            else { return nil }

            return InAppsCheckRequest(
                triggerEvent: event,
                possibleInApps: inAppInfos.map {
                    InAppsCheckRequest.InAppInfo(
                        inAppId: $0.id,
                        targeting: $0.targeting
                    )
                }
            )
        }
    }

    func getInAppFormData(for event: InAppMessageTriggerEvent, inAppId: String) -> InAppFormData? {
        queue.sync {
            guard let inApps = configuration.inAppsByEvent[event],
                  let inApp = inApps.first(where: { $0.id == inAppId }),
                  inApp.formDataVariants.count > 0
            else {
                return nil
            }
            let formData = inApp.formDataVariants[0]
            guard let imageUrl = URL(string: formData.imageUrl) else {
                return nil
            }
            return InAppFormData(imageUrl: imageUrl)
        }
    }

    // MARK: - Private

    private func downloadConfig() {
        URLSession.shared.dataTask(with: configUrl) { [self] data, response, error in
            queue.async { self.completeDownloadTask(data, error: error) }
        }
        .resume()
    }

    private func completeDownloadTask(_ data: Data?, error: Error?) {
        guard let data = data else {
            Log("Failed to download config file. Error: \(error?.localizedDescription ?? "" )")
                .category(.inAppMessages).level(.debug).make()
            return
        }
        Log("Successfuly downloaded config file. Size: \(data.count) Bytes")
            .category(.inAppMessages).level(.debug).make()
        do {
            let config = try jsonDecoder.decode(InAppConfigResponse.self, from: data)
            saveConfigToCache(data)
            setConfigPrepared(config)
        } catch {
            Log("Failed to parse downloaded config file. Error: \(error)")
                .category(.inAppMessages).level(.debug).make()
        }
    }

    private func fetchConfigFromCache() -> InAppConfigResponse? {
        guard let data = inAppConfigRepository.fetchConfigFromCache() else {
            return nil
        }
        guard let config = try? jsonDecoder.decode(InAppConfigResponse.self, from: data) else {
            Log("Failed to parse config file")
                .category(.inAppMessages).level(.debug).make()
            return nil
        }
        Log("Successfuly parsed config file")
            .category(.inAppMessages).level(.debug).make()
        return config
    }

    private func saveConfigToCache(_ data: Data) {
        inAppConfigRepository.saveConfigToCache(data)
    }

    private func setConfigPrepared(_ configResponse: InAppConfigResponse) {
        configuration = mapConfigResponse(configResponse)
        delegate?.didPreparedConfiguration()
    }
}
