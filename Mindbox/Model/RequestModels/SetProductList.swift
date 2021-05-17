//
//  SetProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class SetProductList: Codable {
    public let productList: [ProductList]

    public init(productList: [ProductList]) {
        self.productList = productList
    }
}
