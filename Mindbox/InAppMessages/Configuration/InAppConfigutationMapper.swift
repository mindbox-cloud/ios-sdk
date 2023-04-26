//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation
import MindboxLogger

protocol InAppConfigurationMapperProtocol {
    func mapConfigResponse(_ event: ApplicationEvent?, _ response: InAppConfigResponse,_ completion: @escaping (InAppConfig) -> Void) -> Void
    var targetingChecker: InAppTargetingCheckerProtocol { get set }
}

final class InAppConfigutationMapper: InAppConfigurationMapperProtocol {

    private let customerSegmentsAPI: CustomerSegmentsAPI
    private let inAppsVersion: Int
    var targetingChecker: InAppTargetingCheckerProtocol
    private var geoModel: InAppGeoResponse?
    private let fetcher: NetworkFetcher
    private let sessionTemporaryStorage: SessionTemporaryStorage
    private let persistenceStorage: PersistenceStorage

    private let dispatchGroup = DispatchGroup()

    init(customerSegmentsAPI: CustomerSegmentsAPI,
         inAppsVersion: Int,
         targetingChecker: InAppTargetingCheckerProtocol,
         networkFetcher: NetworkFetcher,
         sessionTemporaryStorage: SessionTemporaryStorage,
         persistenceStorage: PersistenceStorage) {
        self.customerSegmentsAPI = customerSegmentsAPI
        self.inAppsVersion = inAppsVersion
        self.targetingChecker = targetingChecker
        self.fetcher = networkFetcher
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.persistenceStorage = persistenceStorage
    }

    /// Maps config response to business-logic handy InAppConfig model
    func mapConfigResponse(_ event: ApplicationEvent?,
                           _ response: InAppConfigResponse,
                           _ completion: @escaping (InAppConfig) -> Void) {
        let shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        let responseInapps = response.inapps?.filter {
            inAppsVersion >= $0.sdkVersion.min
            && inAppsVersion <= ($0.sdkVersion.max ?? Int.max)
            && !shownInAppsIds.contains($0.id)
        } ?? []

        if responseInapps.isEmpty {
            completeWithEmptyConfig(completion)
            return
        }

        targetingChecker.event = event
        prepareTargetingChecker(for: responseInapps)
        sessionTemporaryStorage.observedCustomOperations = Set(targetingChecker.context.operationsName)
        Logger.common(message: "Shown in-apps ids: [\(shownInAppsIds)]", level: .info, category: .inAppMessages)
        fetchDependencies(model: event?.model) {
            let inappByEvent = self.buildInAppByEvent(inapps: responseInapps)
            completion(InAppConfig(inAppsByEvent: inappByEvent))
        }
    }

    private func completeWithEmptyConfig(_ completion: @escaping (InAppConfig) -> Void) {
        Logger.common(message: "Inapps from config is empty. No inapps to show", level: .debug, category: .inAppMessages)
        completion(InAppConfig(inAppsByEvent: [:]))
    }

    private func prepareTargetingChecker(for inapps: [InAppConfigResponse.InApp]) {
        for inapp in inapps {
            targetingChecker.prepare(targeting: inapp.targeting)
        }
    }

    private func fetchDependencies(model: InappOperationJSONModel?,
                                   _ completion: @escaping () -> Void) {
        fetchSegmentationIfNeeded()
        fetchGeoIfNeeded()
        fetchProductSegmentationIfNeeded(products: model?.viewProduct?.product)

        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    private func fetchSegmentationIfNeeded() {
        if !sessionTemporaryStorage.checkSegmentsRequestCompleted {
            dispatchGroup.enter()
            checkSegmentationRequest { response in
                self.targetingChecker.checkedSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchGeoIfNeeded() {
        if targetingChecker.context.isNeedGeoRequest
            && !sessionTemporaryStorage.geoRequestCompleted {
            dispatchGroup.enter()
            geoRequest { model in
                self.targetingChecker.geoModels = model
                self.dispatchGroup.leave()
            }
        }
    }

    private func fetchProductSegmentationIfNeeded(products: ProductCategory?) {
        if !sessionTemporaryStorage.checkProductSegmentsRequestCompleted,
            let products = products {
            dispatchGroup.enter()
            checkProductSegmentationRequest(products: products) { response in
                self.targetingChecker.checkedProductSegmentations = response
                self.dispatchGroup.leave()
            }
        }
    }

    private func checkSegmentationRequest(_ completion: @escaping ([SegmentationCheckResponse.CustomerSegmentation]?) -> Void) -> Void {

        if sessionTemporaryStorage.checkSegmentsRequestCompleted {
            completion(targetingChecker.checkedSegmentations)
            return
        }

        let arrayOfSegments = Array(Set(targetingChecker.context.segments))
        let segments: [SegmentationCheckRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(nil)
            return
        }

        let model = SegmentationCheckRequest(segmentations: segments)

        customerSegmentsAPI.fetchSegments(model) { response in
            self.sessionTemporaryStorage.checkSegmentsRequestCompleted = true
            guard let response = response,
                  response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)

                completion(nil)
                return
            }

            Logger.common(message: "Customer Segment response: \n\(response)")
            completion(response.customerSegmentations)
        }
    }

    private func checkProductSegmentationRequest(products: ProductCategory,
                                                 _ completion: @escaping ([InAppProductSegmentResponse.CustomerSegmentation]?) -> Void) -> Void {
        if sessionTemporaryStorage.isPresentingInAppMessage {
            return
        }

        let arrayOfSegments = Array(Set(targetingChecker.context.productSegments))
        let segments: [InAppProductSegmentRequest.Segmentation] = arrayOfSegments.map {
            return .init(ids: .init(externalId: $0))
        }

        if segments.isEmpty {
            completion(nil)
            return
        }

        let model = InAppProductSegmentRequest(segmentations: segments, products: [products])

        customerSegmentsAPI.fetchProductSegments(model) { response in
            guard let response = response,
                  response.status == .success else {
                Logger.common(message: "Customer Segment does not exist, or response status not equal to Success. Status: \(String(describing: response?.status))", level: .debug, category: .inAppMessages)

                completion(nil)
                return
            }

            Logger.common(message: "Customer Segment response: \n\(response)")
            var checkedProductSegmentations: [InAppProductSegmentResponse.CustomerSegmentation] = []
            response.products?.forEach {
                checkedProductSegmentations.append(contentsOf: $0.segmentations)
            }

            completion(checkedProductSegmentations)
        }
    }

    private func geoRequest(_ completion: @escaping (InAppGeoResponse?) -> Void) -> Void {
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

    private func buildInAppByEvent(inapps: [InAppConfigResponse.InApp]) -> [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] {
        var inAppsByEvent: [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] = [:]
        for inapp in inapps {
            // Может быть стоит убирать инаппы которые были показаны. Не уточнили еще.
            var triggerEvent: InAppMessageTriggerEvent = .start

            guard targetingChecker.check(targeting: inapp.targeting) else {
                continue
            }

            if let event = self.targetingChecker.event {
                triggerEvent = .applicationEvent(event)
            }

            var inAppsForEvent = inAppsByEvent[triggerEvent] ?? [InAppConfig.InAppInfo]()
            let inAppFormVariants = inapp.form.variants
            let inAppVariants: [SimpleImageInApp] = inAppFormVariants.map {
                return SimpleImageInApp(imageUrl: $0.imageUrl,
                                        redirectUrl: $0.redirectUrl,
                                        intentPayload: $0.intentPayload)
            }

            guard !inAppVariants.isEmpty else { continue }

            let inAppInfo = InAppConfig.InAppInfo(id: inapp.id, formDataVariants: inAppVariants)
            inAppsForEvent.append(inAppInfo)
            inAppsByEvent[triggerEvent] = inAppsForEvent
        }

        self.targetingChecker.event = nil

        return inAppsByEvent
    }
}
