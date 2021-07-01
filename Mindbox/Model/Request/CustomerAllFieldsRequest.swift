//
//  CustomerAllFieldsRequest.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 28.06.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class CustomerAllFieldsRequest: Encodable {
    public var customer: CustomerRequest?
    
    public init(customer: CustomerRequest? = nil) {
        self.customer = customer
    }
}
