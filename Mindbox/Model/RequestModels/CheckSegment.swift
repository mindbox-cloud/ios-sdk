//
//  CheckSegment.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 05.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class CheckSegment: Codable {
    public var segmentations: [Segmentation]

    public init(segmentations: [Segmentation]) {
        self.segmentations = segmentations
    }
}
