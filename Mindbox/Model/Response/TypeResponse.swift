//
//  TypeResponse.swift
//  Mindbox
//
//  Created by Mikhail Plotnikov on 08.07.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

open class TypeResponse: Decodable {
    public let ids: IDS?
    public let name: String?
}
