//
//  RemoveFromProductList.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class RemoveFromProductList: Codable {
    public let removeProductFromList: RemoveProductFromList?

    public init(removeProductFromList: RemoveProductFromList?) {
        self.removeProductFromList = removeProductFromList
    }
}
