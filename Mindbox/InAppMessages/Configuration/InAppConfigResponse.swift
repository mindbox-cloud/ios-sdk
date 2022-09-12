//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

/// Maps config response to business-logic handy InAppConfig model
func mapConfigResponse(_ response: InAppConfigResponse) -> InAppConfig {
    var inAppsByEvent: [InAppMessageTriggerEvent: [InAppConfig.InAppInfo]] = [:]

    for inApp in response.inapps {
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
        if let segmentation = inApp.targeting.payload?.segmention,
           let segment = inApp.targeting.payload?.segment {
            targeting = SegmentationTargeting(segmention: segmentation, segment: segment)
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


struct InAppConfigResponse: Decodable {
    struct InApp: Decodable {
        let id: String
        let targeting: InAppTargeting
        let form: InAppFormVariants
    }

    struct SegmentationTargeting: Decodable {
        let segment: String?
        let segmention: String?
    }

    struct InAppTargeting: Decodable {
        let type: InAppTargetingType?
        let payload: SegmentationTargeting?
    }

    struct InAppForm: Decodable {
        enum CodingKeys: String, CodingKey {
            case type
            case payload
        }

        let payload: InAppFormPayload?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let type = try? container.decode(InAppFormType.self, forKey: .type) else {
                self.payload = nil
                return
            }
            switch type {
            case .simpleImage:
                let simpleImagePayload = try container.decode(SimpleImageInApp.self, forKey: .payload)
                self.payload = .simpleImage(simpleImagePayload)
            }
        }
    }

    struct SimpleImageInApp: Decodable {
        let imageUrl: String
        let redirectUrl: String
        let intentPayload: String
    }

    enum InAppTargetingType: String, Decodable {
        case simple
    }

    enum InAppFormType: String, Decodable {
        case simpleImage
    }

    enum InAppFormPayload {
        case simpleImage(SimpleImageInApp)
    }

    struct InAppFormVariants: Decodable {
        let variants: [InAppForm]
    }

    let inapps: [InApp]
}
