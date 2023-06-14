//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation
import MindboxLogger

struct InAppConfigResponse: Decodable {
    let inapps: [InApp]?
    let monitoring: Monitoring?
    let settings: Settings?
    let abtests: [ABTest]?
    
    enum CodingKeys: String, CodingKey {
        case inapps, monitoring, settings, abtests
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inapps = InAppConfigResponse.decodeIfPresent(container, forKey: .inapps, errorDesc: "Cannot decode InApps")
        monitoring = InAppConfigResponse.decodeIfPresent(container, forKey: .monitoring, errorDesc: "Cannot decode Monitoring")
        settings = InAppConfigResponse.decodeIfPresent(container, forKey: .settings, errorDesc: "Cannot decode Settings")
        
        if let decodedAbtests: [ABTest] = InAppConfigResponse.decodeIfPresent(container, forKey: .abtests, errorDesc: "Cannot decode ABTests"),
           decodedAbtests.allSatisfy({
               ABTestValidator(sdkVersionValidator: SDKVersionValidator(sdkVersionNumeric: Constants.Versions.sdkVersionNumeric)).isValid(item: $0)
           }) {
            abtests = decodedAbtests
        } else {
            abtests = nil
        }
    }
    
    private static func decodeIfPresent<T>(_ container: KeyedDecodingContainer<CodingKeys>,
                                           forKey key: CodingKeys,
                                           errorDesc: String) -> T? where T: Decodable {
        do {
            return try container.decodeIfPresent(T.self, forKey: key)
        } catch {
            Logger.error(.internalError(.init(errorKey: .parsing, reason: errorDesc)))
            return nil
        }
    }
    
    init(inapps: [InApp]? = nil, monitoring: Monitoring? = nil, settings: Settings? = nil, abtests: [ABTest]? = nil) {
        self.inapps = inapps
        self.monitoring = monitoring
        self.settings = settings
        self.abtests = abtests
    }
}
