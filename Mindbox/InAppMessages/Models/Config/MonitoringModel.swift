//
//  MonitoringModel.swift
//  Mindbox
//
//  Created by vailence on 15.06.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

struct Monitoring: Decodable, Equatable {
    let logs: FailableDecodableArray<Logs>

    struct Logs: Decodable, Equatable {
        let requestId: String
        let target: String
        let from: String
        let to: String
    }
}
