//
//  Promocode.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public class PromoCode: Codable {
    public let availableFromDateTimeUtc, availableTillDateTimeUtc: String?
    public let ids: IDS?

    public init(availableFromDateTimeUtc: String?, availableTillDateTimeUtc: String?, ids: IDS?) {
        self.availableFromDateTimeUtc = availableFromDateTimeUtc
        self.availableTillDateTimeUtc = availableTillDateTimeUtc
        self.ids = ids
    }

    // MARK: - IDS

    public class IDS: Codable {
        public let value: String?

        public init(value: String?) {
            self.value = value
        }
    }
}
