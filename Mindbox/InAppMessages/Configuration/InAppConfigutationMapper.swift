//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation

class InAppConfigutationMapper {
    
    private let customerSegmentsAPI: CustomerSegmentsAPI
    private let inAppsVersion: Int
    
    init(customerSegmentsAPI: CustomerSegmentsAPI, inAppsVersion: Int) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
    }
    
    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ response: InAppConfigResponse) -> InAppConfig {
        var inAppsByEvent: [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] = [:]
        
        let inapps = response.inapps
            .compactMap { $0.value }
            .filter {
                inAppsVersion >= $0.sdkVersion.min
                && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
            }
        
        for inapp in inapps {
            var event: InAppMessageTriggerEvent?
            switch inapp.targeting.type {
            case .and, .or, .true:
                event = .start
            }
            
            guard let inAppTriggerEvent = event else {
                continue
            }
            
            var inAppsForEvent = inAppsByEvent[inAppTriggerEvent] ?? [InAppConfig.InAppInfo]()
            let inAppFormVariants = inapp.form.variants
            let inAppVariants: [InAppVariants] = inAppFormVariants.map {
                return InAppVariants(imageUrl: $0.imageUrl,
                                     redirectUrl: $0.redirectUrl,
                                     intentPayload: $0.intentPayload)
            }
            
            guard !inAppVariants.isEmpty else { continue }
            
            let inAppInfo = InAppConfig.InAppInfo(id: inapp.id, formDataVariants: inAppVariants)
            inAppsForEvent.append(inAppInfo)
            inAppsByEvent[inAppTriggerEvent] = inAppsForEvent
            
            //
            //            var targeting: SegmentationTargeting?
            //            if let segmentation = inApp.targeting.payload.segmentation,
            //               let segment = inApp.targeting.payload.segment {
            //                targeting = SegmentationTargeting(segmentation: segmentation, segment: segment)
            //            }
            //
            //            let inAppInfo = InAppConfig.InAppInfo(
            //                id: inApp.id,
            //                targeting: targeting,
            //                formDataVariants: simpleImageInApps
            //            )
            //
            //            inAppsForEvent.append(inAppInfo)
            //            inAppsByEvent[inAppTriggetEvent] = inAppsForEvent
            
            
            //            switch inapp.targeting.type {
            //            case .and:
            //                doAnd(with: inapp.targeting.nodes)
            //            case .or:
            //                break
            //            case .true:
            //                continue
            //            }
        }
        
        return InAppConfig(inAppsByEvent: inAppsByEvent)
    }
    
    private func doAnd(with nodes: [InAppConfigResponse.TargetingNode]?) {
        guard let nodes = nodes else { return }
        
        for node in nodes {
            if node.type == .true {
                print("TRUE")
            } else {
                print("OTHER NODE TYPES")
            }
        }
    }
}
