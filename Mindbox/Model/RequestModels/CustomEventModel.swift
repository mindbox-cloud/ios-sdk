//
//  CustomEventModel.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 18.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CustomEventModel: Codable {
    public var customer: Customer
    public var productList: [ProductList]
    public var order: Order
    
    public init(customer: Customer, productList: [ProductList], order: Order) {
        self.customer = customer
        self.productList = productList
        self.order = order
    }

}
