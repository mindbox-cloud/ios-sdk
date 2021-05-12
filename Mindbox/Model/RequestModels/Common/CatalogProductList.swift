//
//  CatalogProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CatalogProductList: Codable {
    public let area: Area?
    public let items: [Item]?

    public init(area: Area?, items: [Item]) {
        self.area = area
        self.items = items
    }
}
