//
//  Segmentation.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - Segmentation

public class Segmentation: Codable {
    public var ids: IDS?

    public init(ids: IDS) {
        self.ids = ids
    }

    // MARK: - IDS

    public class IDS: Codable {
        public var externalId: String?

        public init(externalId: String) {
            self.externalId = externalId
        }
    }
}
