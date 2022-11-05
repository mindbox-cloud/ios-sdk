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
        init(type: InAppConfigResponse.InAppTargetingType, payload: InAppConfigResponse.SegmentationTargeting) {
            self.type = type
            self.payload = payload
        }

        let type: InAppTargetingType
        let payload: SegmentationTargeting

        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(InAppTargetingType.self, forKey: CodingKeys.type)
            switch type {
            case .simple:
                let payload = try SegmentationTargeting(from: decoder)
                if (payload.segment == nil && payload.segmentation == nil) || (payload.segment != nil && payload.segmentation != nil) {
                    self.payload = payload
                } else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: decoder.codingPath,
                            debugDescription: "Segment and segmentation in payload should be either both nil or both not nill"
                        )
                    )
                }
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
