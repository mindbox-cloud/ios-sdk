//
//  ProductCategory.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class ProductCategory: Codable {
    public var ids: IDS?

    public init(ids: IDS?) {
        self.ids = ids
    }

    // MARK: - IDS

    public class IDS: Codable {
        public var website: String?

        public init(website: String?) {
            self.website = website
        }
    }
}
