//
//  CatalogProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CatalogProductList: Codable {
    public var area: Area?
    public var items: [Item]?

    public init(area: Area?, items: [Item]) {
        self.area = area
        self.items = items
    }
}
