//
//  PlaceholderResponse.swift
//  Mindbox
//
//  Created by lbr on 08.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

open class PlaceholderResponse: Codable {
    public let ids: IDS?
    public let content: [ContentResponse]?
}
