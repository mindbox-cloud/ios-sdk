//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation
import MindboxLogger

protocol InAppConfigurationMapperProtocol {
    func mapConfigResponse(_ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {
    
    private let customerSegmentsAPI: CustomerSegmentsAPI
    private let inAppsVersion: Int
    private var targetingChecker: InAppTargetingCheckerProtocol
    private var geoModel: InAppGeoResponse?
    private let fetcher: NetworkFetcher
    
    private let dispatchGroup = DispatchGroup()
    
    init(customerSegmentsAPI: CustomerSegmentsAPI,
         inAppsVersion: Int,
         targetingChecker: InAppTargetingCheckerProtocol,
         networkFetcher: NetworkFetcher) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
        self.targetingChecker = targetingChecker
        self.fetcher = networkFetcher
    }
    
    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void {
        guard let responseInapps = response.inapps else {
            Logger.common(message: "Inapps from conifig is Empty. No inapps to show", level: .debug, category: .inAppMessages)
            completion(InAppConfig(inAppsByEvent: [:]))
            return
        }
        
        // Check inapps for compatible versions
        let inapps = responseInapps
            .filter {
                inAppsVersion >= $0.sdkVersion.min
                && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
            }
        
        if inapps.isEmpty {
            Logger.common(message: "Inapps from conifig is Empty. No inapps to show", level: .debug, category: .inAppMessages)
            completion(InAppConfig(inAppsByEvent: [:]))
            return
        }
        
        for inapp in inapps {
            targetingChecker.prepare(targeting: inapp.targeting)
            // Loop inapps for all Segment types and collect ids.
        }
        
        dispatchGroup.enter()
        checkSegmentationRequest() { response in
            self.targetingChecker.checkedSegmentations = response.customerSegmentations
            self.dispatchGroup.leave()
        }
        
        if targetingChecker.context.isNeedGeoRequest {
            dispatchGroup.enter()
            geoRequest { model in
                self.targetingChecker.geoModels = model
                self.dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let inappByEvent = self.buildInAppByEvent(inapps: inapps)
            completion(InAppConfig(inAppsByEvent: inappByEvent))
        }
    }

    private func checkSegmentationRequest(_ completion: @escaping (SegmentationCheckResponse) -> Void) -> Void {
        let arrayOfSegments = Array(Set(targetingChecker.context.segments))
        let segments: [SegmentationCheckRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }
        
        if segments.isEmpty {
            completion(.init(status: .success, customerSegmentations: nil))
            return
        }
        
        let model = SegmentationCheckRequest(segmentations: segments)
        
        customerSegmentsAPI.fetchSegments(model) { response in
            guard let response = response,
                  response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)
                completion(.init(status: .unknown, customerSegmentations: nil))
                return
            }
            
            Logger.common(message: "Customer Segment response: \n\(response)")
            completion(response)
        }
    }
    
    private func geoRequest(_ completion: @escaping (InAppGeoResponse?) -> Void) -> Void {
        let route = FetchInAppGeoRoute()
        fetcher.request(type: InAppGeoResponse.self, route: route, needBaseResponse: false) { response in
            switch response {
            case .success(let result):
                completion(result)
            case .failure(let error):
                Logger.error(error)
                completion(nil)
            }
        }
    }
    
    private func buildInAppByEvent(inapps: [InAppConfigResponse.InApp]) -> [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] {
        var inAppsByEvent: [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] = [:]
        for inapp in inapps {
            // Может быть стоит убирать инаппы которые были показаны. Не уточнили еще.
            let event: InAppMessageTriggerEvent = .start

            guard targetingChecker.check(targeting: inapp.targeting) else {
                continue
            }

            var inAppsForEvent = inAppsByEvent[event] ?? [InAppConfig.InAppInfo]()
            let inAppFormVariants = inapp.form.variants
            let inAppVariants: [SimpleImageInApp] = inAppFormVariants.map {
                return SimpleImageInApp(imageUrl: $0.imageUrl,
                                        redirectUrl: $0.redirectUrl,
                                        intentPayload: $0.intentPayload)
            }

            guard !inAppVariants.isEmpty else { continue }

            let inAppInfo = InAppConfig.InAppInfo(id: inapp.id, formDataVariants: inAppVariants)
            inAppsForEvent.append(inAppInfo)
            inAppsByEvent[event] = inAppsForEvent
        }

        return inAppsByEvent
    }
}
