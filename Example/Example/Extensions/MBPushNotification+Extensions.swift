//
//  MBPushNotification+Extensions.swift
//  Example
//
//  Created by Sergei Semko on 6/10/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import Mindbox

public extension MBPushNotification {
    init?(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            self = try decoder.decode(Self.self, from: jsonData)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    var decodedPayload: Payload? {
        guard let payloadData = payload?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: payloadData)
    }
}
