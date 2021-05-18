//
//  CreateCustomer.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CreateCustomer: Codable {
    public var customer: Customer

    public init(customer: Customer) {
        self.customer = customer
    }
}
