//
//  AddAction.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - AddAction

public class AddAction: Codable {
    public let customerAction: CustomerAction?
    public let pointOfContact: String?

    public init(
        customerAction: CustomerAction?,
        pointOfContact: String?
    ) {
        self.customerAction = customerAction
        self.pointOfContact = pointOfContact
    }
}
