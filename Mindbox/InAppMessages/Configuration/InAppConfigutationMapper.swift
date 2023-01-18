//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation

protocol InAppConfigurationMapperProtocol {
    func mapConfigResponse(_ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void
    func setGeo(_ data: InAppGeoResponse?)
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {
    
    private let customerSegmentsAPI: CustomerSegmentsAPI
    private let inAppsVersion: Int
    private var targetingChecker: InAppTargetingCheckerProtocol
    private var geoModel: InAppGeoResponse?
    
    init(customerSegmentsAPI: CustomerSegmentsAPI, inAppsVersion: Int, targetingChecker: InAppTargetingCheckerProtocol) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
        self.targetingChecker = targetingChecker
    }
    
    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void {
        // Check inapps for compatible versions
        let inapps = response.inapps
            .filter {
                inAppsVersion >= $0.sdkVersion.min
                && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
            }
        
        if inapps.isEmpty {
            completion(InAppConfig(inAppsByEvent: [:]))
            return
        }
        
        for inapp in inapps {
            targetingChecker.prepare(targeting: inapp.targeting)
            // Loop inapps for all Segment types and collect ids.
        }
        
        checkSegmentationRequest() { response in
            self.targetingChecker.checkedSegmentations = response.customerSegmentations
            let inappByEvent = self.buildInAppByEvent(inapps: inapps)
            completion(InAppConfig(inAppsByEvent: inappByEvent))
            return
        }
    }
    func setGeo(_ data: InAppGeoResponse?) {
        self.geoModel = data
    }
    private func checkSegmentationRequest(_ completion: @escaping (SegmentationCheckResponse) -> Void) -> Void {
        let arrayOfSegments = Array(Set(targetingChecker.context.segments))
        let segments: [SegmentationCheckRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }
        
        let model = SegmentationCheckRequest(segmentations: segments)
        
        customerSegmentsAPI.fetchSegments(model) { response in
            guard let response = response,
                  response.status == .success else {
                completion(.init(status: .unknown, customerSegmentations: []))
                return
            }
            
            completion(response)
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
