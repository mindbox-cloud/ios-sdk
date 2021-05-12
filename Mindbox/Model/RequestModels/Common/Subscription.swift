//
//  Subscription.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Subscription
public class Subscription: Codable {
    public let brand, pointOfContact, topic: String?
    public let isSubscribed: Bool?

    public init(brand: String?, pointOfContact: String?, topic: String?, isSubscribed: Bool) {
        self.brand = brand
        self.pointOfContact = pointOfContact
        self.topic = topic
        self.isSubscribed = isSubscribed
    }
}
