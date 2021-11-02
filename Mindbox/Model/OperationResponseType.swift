//
//  OperationResponseType.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.05.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public protocol OperationResponseType: Codable {
    var status: Status { get }
}
