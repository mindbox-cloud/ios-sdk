//
//  ViewProductCategory.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ViewProductCategory: Codable {
    public var productCategory: ProductCategory?
    public var customerAction: CustomerAction?

    public init(productCategory: ProductCategory?, customerAction: CustomerAction?) {
        self.productCategory = productCategory
        self.customerAction = customerAction
    }
}
