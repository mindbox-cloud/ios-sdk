//
//  DeleteCard.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class DeleteCard: Codable {
    public let discountCard: DiscountCard?

    public init(discountCard: DiscountCard?) {
        self.discountCard = discountCard
    }
}
