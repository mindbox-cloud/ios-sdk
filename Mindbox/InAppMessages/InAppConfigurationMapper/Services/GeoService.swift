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
    var sessionTemporaryStorage: SessionTemporaryStorage
    var targetingChecker: InAppTargetingCheckerProtocol

    init(fetcher: NetworkFetcher,
         sessionTemporaryStorage: SessionTemporaryStorage,
         targetingChecker: InAppTargetingCheckerProtocol) {
        self.fetcher = fetcher
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.targetingChecker = targetingChecker
    }

    func geoRequest(completion: @escaping (InAppGeoResponse?) -> Void) {
        if sessionTemporaryStorage.geoRequestCompleted {
            completion(targetingChecker.geoModels)
            return
        }

        let route = FetchInAppGeoRoute()
        fetcher.request(type: InAppGeoResponse.self, route: route, needBaseResponse: false) { response in
            self.sessionTemporaryStorage.geoRequestCompleted = true
            switch response {
            case .success(let result):
                completion(result)
            case .failure(let error):
                Logger.error(error)
                completion(nil)
            }
        }
    }
}
