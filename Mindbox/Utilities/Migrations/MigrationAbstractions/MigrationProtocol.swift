//
//  MigrationProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 8/1/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol MigrationProtocol {

    var description: String { get }

    var isNeeded: Bool { get }

    var version: Int { get }

    func run() throws
}
