//
//  ConfigResponse.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation
import MindboxLogger

struct ConfigResponse: Decodable {
    var inapps: FailableDecodableArray<InAppDTO>?
    let monitoring: Monitoring?
    let settings: Settings?
    let abtests: [ABTest]?

    enum CodingKeys: String, CodingKey {
        case inapps, monitoring, settings, abtests
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.inapps = try? container.decodeIfPresent(FailableDecodableArray<InAppDTO>.self, forKey: .inapps)
        self.monitoring = ConfigResponse.decodeIfPresent(container, forKey: .monitoring, errorDesc: "Cannot decode Monitoring")
        self.settings = ConfigResponse.decodeIfPresent(container, forKey: .settings, errorDesc: "Cannot decode Settings")

        let abTestValidator = DI.injectOrFail(ABTestValidator.self)
        if let decodedAbtests: [ABTest] = ConfigResponse.decodeIfPresent(container, forKey: .abtests, errorDesc: "Cannot decode ABTests"),
           decodedAbtests.allSatisfy({
               abTestValidator.isValid(item: $0)
           }) {
            self.abtests = decodedAbtests
        } else {
            self.abtests = nil
        }
    }

    private static func decodeIfPresent<T>(_ container: KeyedDecodingContainer<CodingKeys>,
                                           forKey key: CodingKeys,
                                           errorDesc: String) -> T? where T: Decodable {
        do {
            return try container.decodeIfPresent(T.self, forKey: key)
        } catch {
            Logger.common(message: errorDesc)
            return nil
        }
    }
}

extension ConfigResponse {
    init(inapps: FailableDecodableArray<InAppDTO>? = nil, monitoring: Monitoring? = nil, settings: Settings? = nil, abtests: [ABTest]? = nil) {
        self.inapps = inapps
        self.monitoring = monitoring
        self.settings = settings
        self.abtests = abtests
    }
}
