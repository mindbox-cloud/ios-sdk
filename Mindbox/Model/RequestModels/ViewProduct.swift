//
//  ViewProduct.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ViewProduct: Codable {
    public let viewProduct: SubViewProduct?

    public init(viewProduct: SubViewProduct?) {
        self.viewProduct = viewProduct
    }
}
