//
//  SetCountInProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class SetCountInProductList: Codable {
    public let setProductCountInList: ProductList

    public init(setProductCountInList: ProductList) {
        self.setProductCountInList = setProductCountInList
    }
}
