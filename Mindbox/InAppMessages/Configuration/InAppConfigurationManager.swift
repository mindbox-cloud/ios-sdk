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

    private let configUrl = URL(string: "https://web-bucket-inapps-configs-staging.storage.yandexcloud.net/byendpoint/someTestMobileEndpoint.json")!
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

    func buildInAppRequest(event: String, _ completion: @escaping (InAppRequest?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(InAppRequest())
        }
    }

    func buildInAppMessage(inAppResponse: InAppResponse) -> InAppMessage {
        return InAppMessage(imageUrl: URL(string: "https://random.imagecdn.app/500/150")!)
    }

    // MARK: - Private

    private func downloadConfig() {
        URLSession.shared.dataTask(with: configUrl) { [self] data, response, error in
            queue.async { self.completeDownloadTask(data, error: error) }
        }
        .resume()
    }

    private func completeDownloadTask(_ data: Data?, error: Error?) {
        guard let data = data, let config = try? jsonDecoder.decode(InAppConfig.self, from: data) else {
            return
        }
        saveConfigToCache(data)
        setConfigPrepared(config)
    }

    private func fetchConfigFromCache() -> InAppConfig? {
        guard let data = inAppConfigRepository.fetchConfigFromCache() else {
            return nil
        }
        guard let config = try? jsonDecoder.decode(InAppConfig.self, from: data) else {
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

    private func setConfigPrepared(_ config: InAppConfig) {
        configuration = config
        delegate?.didPreparedConfiguration()
    }

    private var inAppConfigFileUrl: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("InAppMessagesConfiguration.json")
    }
}

struct InAppConfig: Decodable {

}
