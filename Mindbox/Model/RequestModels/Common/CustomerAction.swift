//
//  CustomerAction.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

// MARK: - CustomerAction

public class CustomerAction: Codable {
    public let customFields: CustomFields?

    public init(customFields: CustomFields?) {
        self.customFields = customFields
    }
}
