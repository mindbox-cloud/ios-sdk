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
    private var configuration: InAppConfigResponse!
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
            guard let configuration = configuration else { return nil }
            switch event {
            case .start:
                let possibleInAppsForEvent = configuration.inapps
                    .filter({ $0.targeting.type == .simple })
                    .map {
                        InAppsCheckRequest.InAppInfo(
                            inAppId: $0.id,
                            targetings: [] // todo map targeting
                        )
                    }

                return InAppsCheckRequest(
                    triggerEvent: event,
                    possibleInApps: possibleInAppsForEvent
                )
            case .applicationEvent:
                return nil
            }
        }
    }

    func buildInAppMessage(inAppResponse: InAppResponse) -> InAppMessage? {
        queue.sync {
            let inAppsToShow = configuration.inapps.filter { inAppResponse.inAppIds.contains($0.id)  }
            guard let firstInAppToShow = inAppsToShow.first,
                  let inAppFormData = firstInAppToShow.form.variants.first?.payload else { return nil }

            switch inAppFormData {
            case let .simpleImage(simpleImageInApp):
                guard let imageUrl = URL(string: simpleImageInApp.imageUrl) else {
                    return nil
                }
                return InAppMessage(imageUrl: imageUrl)
            }
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

    private func setConfigPrepared(_ config: InAppConfigResponse) {
        configuration = config
        delegate?.didPreparedConfiguration()
    }
}
