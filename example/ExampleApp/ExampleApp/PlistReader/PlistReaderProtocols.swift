//
//  PlistReaderProtocols.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/13/24.
//

import Foundation

protocol PlistReader {
    var endpoint: String { get }
    var domain: String { get }
}

protocol PlistReaderOperation {
    var operationSystemName: String { get }
}
