//
//  ViewProductCategory.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ViewProductCategory: Codable {
    public let productCategory: ProductCategory?
    public let customerAction: CustomerAction?

    public init(productCategory: ProductCategory?, customerAction: CustomerAction?) {
        self.productCategory = productCategory
        self.customerAction = customerAction
    }
}
