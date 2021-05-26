//
//  ViewCategory.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ViewCategory: Codable {
    public var viewProductCategory: ViewProductCategory?

    public init(viewProductCategory: ViewProductCategory?) {
        self.viewProductCategory = viewProductCategory
    }
}
