//
//  CalculateCatalog.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CalculateCatalog: Codable {
    public var productList: CatalogProductList

    public init(productList: CatalogProductList) {
        self.productList = productList
    }
}
