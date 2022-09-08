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
                let simpleImagePayload = try container.decode(SimpleImageInApp.self, forKey: .type)
                self.payload = .simpleImage(simpleImagePayload)
            }
        }
    }

    let inapps: [InApp]
}

enum InAppTargetingType: String, Decodable {
    case sample
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

//{
//    "inapps": [
//        {
//            "id": "8dc2094d-2f9d-4f1d-b247-56d2e8c17e5e",
//            "targeting": {
//                "type": "simple",
//                "payload": {
//                    "segmentation": "d2554859-03cf-4b80-b972-25eb54afc68c",
//                    "segment": "d2554859-03cf-4b80-b972-25eb54afc68c"
//                }
//            },
//            "form": {
//                "variants": [
//                    {
//                        "type": "simpleImage",
//                        "payload": {
//                            "imageUrl": "https://placeimg.com/640/360/any",
//                            "redirectUrl": "https://mpush-test.mindbox.ru/newcustomers/customers?filter=segment(s(20)e(filter-mode(Present))h(f)a(f)n(f))",
//                            "intentPayload": "ooo some custom intent payload ooo"
//                        }
//                    }
//                ]
//            }
//        }
//    ]
//}
