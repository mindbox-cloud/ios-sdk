//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {
    struct InApp: Decodable {
        let id: String
        let targeting: InAppTargeting
        let form: InAppFormVariants
    }

    struct InAppTargeting: Decodable {
        let type: InAppTargetingType?
    }

    struct InAppFormVariants: Decodable {
        let variants: [InAppForm]
    }

    struct InAppForm: Decodable {
        enum CodingKeys: String, CodingKey {
            case type
            case payload
        }

        var payload: InAppFormPayload?

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

    let inapps: [InApp]
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

struct SimpleImageInApp: Decodable {
    let imageUrl: String
    let redirectUrl: String
    let intentPayload: String
}
