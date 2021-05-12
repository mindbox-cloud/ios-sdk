//
//  AddToProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class AddToProductList: Codable {
    public let addProductToList: AddProductToList?

    public init(addProductToList: AddProductToList?) {
        self.addProductToList = addProductToList
    }
}
