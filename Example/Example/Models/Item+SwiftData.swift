//
//  Item+SwiftData.swift
//  Example
//
//  Created by Sergei Semko on 6/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
//import Mindbox
import SwiftData

@Model
public final class Item {
    public var timestamp: Date
    public var mbPushNotification: PushNotification
    
    public init(timestamp: Date, pushNotification: PushNotification) {
        self.timestamp = timestamp
        self.mbPushNotification = pushNotification
    }
}

public struct PushNotification: Codable {
    public let title: String?
    public let body: String?
    public let clickUrl: String?
    public let imageUrl: String?
    public let payload: String?
    public let uniqueKey: String?
    
    var decodedPayload: Payload? {
        guard let payloadData = payload?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: payloadData)
    }
}
//
//extension PushNotification {
//    init?(jsonString: String) {
//        guard let jsonData = jsonString.data(using: .utf8) else {
//            return nil
//        }
//        
//        do {
//            let decoder = JSONDecoder()
//            self = try decoder.decode(Self.self, from: jsonData)
//        } catch {
//            print(error.localizedDescription)
//            return nil
//        }
//    }
//}
