//
//  BaseAddressesModel.swift
//  Mindbox
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

extension Settings {
    /// DTO for `settings.baseAddresses` in the mobile JSON config
    /// (`/mobile/byendpoint/{endpointId}.json`).
    struct BaseAddresses: Decodable, Equatable {
        let operations: String?

        enum CodingKeys: CodingKey {
            case operations
        }
    }
}

extension Settings.BaseAddresses {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.operations = try? container.decodeIfPresent(String.self, forKey: .operations)
    }
}
