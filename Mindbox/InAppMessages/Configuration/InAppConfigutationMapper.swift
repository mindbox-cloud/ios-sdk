//
//  InAppConfigutationMapper.swift
//  Mindbox
//
//  Created by Максим Казаков on 12.09.2022.
//

import Foundation

class InAppConfigutationMapper {
    private let inAppsVersion: Int

    init(inAppsVersion: Int) {
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

        for inApp in inapps {
            var event: InAppMessageTriggerEvent?
            if inApp.targeting.type == .simple {
                event = .start
            }
            guard let inAppTriggetEvent = event else {
                continue
            }

            var inAppsForEvent = inAppsByEvent[inAppTriggetEvent] ?? [InAppConfig.InAppInfo]()

            let inAppFormVariants = inApp.form.variants.compactMap { $0.payload }
            let simpleImageInApps: [SimpleImageInApp] = inAppFormVariants.map {
                switch $0 {
                case let .simpleImage(simpleImageInApp):
                    return SimpleImageInApp(
                        imageUrl: simpleImageInApp.imageUrl,
                        redirectUrl: simpleImageInApp.redirectUrl,
                        intentPayload: simpleImageInApp.intentPayload
                    )
                }
            }
            guard !simpleImageInApps.isEmpty else {
                continue
            }

            var targeting: SegmentationTargeting?
            if let segmentation = inApp.targeting.payload.segmentation,
               let segment = inApp.targeting.payload.segment {
                targeting = SegmentationTargeting(segmentation: segmentation, segment: segment)
            }

            let inAppInfo = InAppConfig.InAppInfo(
                id: inApp.id,
                targeting: targeting,
                formDataVariants: simpleImageInApps
            )

            inAppsForEvent.append(inAppInfo)
            inAppsByEvent[inAppTriggetEvent] = inAppsForEvent
        }

        return InAppConfig(inAppsByEvent: inAppsByEvent)
    }
}
