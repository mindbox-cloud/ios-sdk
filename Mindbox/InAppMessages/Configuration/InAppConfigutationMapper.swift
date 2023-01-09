//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation

final class InAppConfigutationMapper {
    
    private let customerSegmentsAPI: CustomerSegmentsAPI
    private let inAppsVersion: Int
    private var segmentations: [String: Int] = [:]
    private var checkedSegmentations: [SegmentationCheckResponse.CustomerSegmentation] = []
    
    init(customerSegmentsAPI: CustomerSegmentsAPI, inAppsVersion: Int) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
    }
    
    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void {
        // Check inapps for compatible versions
        let inapps = response.inapps
            .compactMap { $0.value }
            .filter {
                inAppsVersion >= $0.sdkVersion.min
                && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
            }
        
        if inapps.isEmpty {
            completion(InAppConfig(inAppsByEvent: [:]))
            return
        }
        
        // Loop inapps for all Segment types and collect ids.
        for inapp in inapps {
            handleRootNode(inapp.targeting.type, nodes: inapp.targeting.nodes)
        }
        
        checkSegmentationRequest { response in
            self.checkedSegmentations = response.customerSegmentations
            let inappByEvent = self.buildInAppByEvent(inapps: inapps)
            completion(InAppConfig(inAppsByEvent: inappByEvent))
            return
        }
    }
    
    @discardableResult
    private func handleRootNode(_ root: InAppConfigResponse.TargetingType, nodes: [InAppConfigResponse.TargetingNode]?) -> Bool {
        // Result means that this inapp is eligible by any targeting params.
        var result: Bool = false
        
        switch root {
        case .and, .or:
            guard let nestedNodes = nodes else { break }
            result = handleAndOrActions(rootType: root, nodes: nestedNodes)
        case .true:
            result = true
        case .segment:
            break
        }
        
        return result
    }
    
    private func handleAndOrActions(rootType: InAppConfigResponse.TargetingType, nodes: [InAppConfigResponse.TargetingNode]) -> Bool {
        var results: [Bool] = []
        for node in nodes {
            switch node.type {
            case .and, .or:
                guard let nestedNodes = node.nodes else { break }
                let result = handleAndOrActions(rootType: node.type, nodes: nestedNodes)
                results.append(result)
            case .true:
                results.append(true)
            case .segment:
                guard let id = node.segmentationExternalId else { break }
                addToSegmentHashTable(id)
                
                results.append(checkedSegmentations.contains(where: {
                    if node.kind == .positive {
                        return $0.segment?.ids?.externalId == node.segmentExternalId
                    } else {
                        return $0.segment?.ids?.externalId != node.segmentExternalId
                    }
                }))
            }
        }
        
        if rootType == .and {
            return !results.contains(false)
        } else if rootType == .or {
            return results.contains(true)
        }
        
        return false
    }
    
    private func checkSegmentationRequest(_ completion: @escaping (SegmentationCheckResponse) -> Void) -> Void {
        let arrayOfSegments = Array(segmentations.keys)
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
            var event: InAppMessageTriggerEvent?
            switch inapp.targeting.type {
            case .and, .or, .true, .segment:
                event = .start
            }
            
            guard let inAppTriggerEvent = event,
                  handleRootNode(inapp.targeting.type, nodes: inapp.targeting.nodes) else {
                continue
            }
            
            var inAppsForEvent = inAppsByEvent[inAppTriggerEvent] ?? [InAppConfig.InAppInfo]()
            let inAppFormVariants = inapp.form.variants
            let inAppVariants: [SimpleImageInApp] = inAppFormVariants.map {
                return SimpleImageInApp(imageUrl: $0.imageUrl,
                                        redirectUrl: $0.redirectUrl,
                                        intentPayload: $0.intentPayload)
            }
            
            guard !inAppVariants.isEmpty else { continue }
            
            let inAppInfo = InAppConfig.InAppInfo(id: inapp.id, formDataVariants: inAppVariants)
            inAppsForEvent.append(inAppInfo)
            inAppsByEvent[inAppTriggerEvent] = inAppsForEvent
        }
        
        return inAppsByEvent
    }
      
    private func addToSegmentHashTable(_ id: String) {
        segmentations[id, default: 0] += 1
    }
}
