//
//  OperationResponseType.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 26.05.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

public protocol OperationResponseType: Codable {
    var status: Status { get }
}
