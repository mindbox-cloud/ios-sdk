//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {

    struct SdkVersion: Decodable {
        let min: Int
        let max: Int?
    }

    struct InApp: Decodable {
        let id: String
        let sdkVersion: SdkVersion
        let targeting: InAppTargeting
        let form: InAppFormVariants
    }

    struct SegmentationTargeting: Decodable {
        let segment: String?
        let segmentation: String?
    }

    struct InAppTargeting: Decodable {
        init(type: InAppConfigResponse.InAppTargetingType? = nil, payload: InAppConfigResponse.SegmentationTargeting? = nil) {
            self.type = type
            self.payload = payload
        }

        let type: InAppTargetingType?
        let payload: SegmentationTargeting?

        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try? container.decodeIfPresent(InAppTargetingType.self, forKey: CodingKeys.type)
            switch type {
            case .simple:
                self.payload = try? SegmentationTargeting(from: decoder)
            case .none:
                self.payload = nil
            }
        }
    }

    struct InAppForm: Decodable {
        init(payload: InAppConfigResponse.InAppFormPayload? = nil) {
            self.payload = payload
        }

        enum CodingKeys: String, CodingKey {
            case type = "$type"
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
                let simpleImagePayload = try SimpleImageInApp(from: decoder)
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

    let inapps: [FailableDecodable<InApp>]
}

struct FailableDecodable<T: Decodable>: Decodable {
    init(value: T? = nil) {
        self.value = value
    }

    let value: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(T.self)
    }
}
