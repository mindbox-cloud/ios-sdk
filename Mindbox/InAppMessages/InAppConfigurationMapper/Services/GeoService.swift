//
//  GeoService.swift
//  Mindbox
//
//  Created by vailence on 13.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol GeoServiceProtocol {
    func geoRequest(completion: @escaping (Result<InAppGeoResponse?, MindboxError>) -> Void)
}

class GeoService: GeoServiceProtocol {
    let fetcher: NetworkFetcher
    var targetingChecker: InAppTargetingCheckerProtocol

    init(fetcher: NetworkFetcher,
         targetingChecker: InAppTargetingCheckerProtocol) {
        self.fetcher = fetcher
        self.targetingChecker = targetingChecker
    }

    func geoRequest(completion: @escaping (Result<InAppGeoResponse?, MindboxError>) -> Void) {
        if let cachedResult = SessionTemporaryStorage.shared.geoRequestResult {
            completion(cachedResult)
            return
        }

        let route = FetchInAppGeoRoute()
        fetcher.request(type: InAppGeoResponse.self, route: route, needBaseResponse: false) { response in
            switch response {
            case .success(let result):
                SessionTemporaryStorage.shared.geoRequestResult = .success(result)
                self.targetingChecker.geoModels = result
                completion(.success(result))
            case .failure(let error):
                SessionTemporaryStorage.shared.geoRequestResult = .failure(error)
                self.targetingChecker.geoModels = nil
                Logger.error(error.asLoggerError())
                completion(.failure(error))
            }
        }
    }
}
