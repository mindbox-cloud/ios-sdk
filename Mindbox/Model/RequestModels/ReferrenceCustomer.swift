//
//  ReferrenceCustomer.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ReferrenceCustomer: Codable {
    public var referencedCustomer: ReferencedCustomer?

    public init(referencedCustomer: ReferencedCustomer?) {
        self.referencedCustomer = referencedCustomer
    }
}
