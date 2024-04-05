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
    func geoRequest(completion: @escaping (InAppGeoResponse?) -> Void)
}

class GeoService: GeoServiceProtocol {
    let fetcher: NetworkFetcher
    var targetingChecker: InAppTargetingCheckerProtocol

    init(fetcher: NetworkFetcher,
         targetingChecker: InAppTargetingCheckerProtocol) {
        self.fetcher = fetcher
        self.targetingChecker = targetingChecker
    }

    func geoRequest(completion: @escaping (InAppGeoResponse?) -> Void) {
        if SessionTemporaryStorage.shared.geoRequestCompleted {
            completion(targetingChecker.geoModels)
            return
        }

        let route = FetchInAppGeoRoute()
        fetcher.request(type: InAppGeoResponse.self, route: route, needBaseResponse: false) { response in
            SessionTemporaryStorage.shared.geoRequestCompleted = true
            switch response {
            case .success(let result):
                completion(result)
            case .failure(let error):
                Logger.error(error.asLoggerError())
                completion(nil)
            }
        }
    }
}
