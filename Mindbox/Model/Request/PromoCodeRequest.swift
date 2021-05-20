//
//  Promocode.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 06.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class PromoCodeRequest: Encodable {
    public var availableFromDateTimeUtc: DateTimeRequest?
    public var availableTillDateTimeUtc: DateTimeRequest?
    public var ids: IDS?

    public init(
        availableFromDateTimeUtc: DateTimeRequest? = nil,
        availableTillDateTimeUtc: DateTimeRequest? = nil,
        ids: IDS? = nil
    ) {
        self.availableFromDateTimeUtc = availableFromDateTimeUtc
        self.availableTillDateTimeUtc = availableTillDateTimeUtc
        self.ids = ids
    }
}
