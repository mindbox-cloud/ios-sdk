//
//  GetConfigFunc.swift
//  MindboxTests
//
//  Created by Sergei Semko on 9/11/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

protocol Configurable: RawRepresentable where RawValue == String {
    associatedtype DecodeType: Decodable
    func getConfig() throws -> DecodeType
}

extension Configurable {
    func getConfig() throws -> DecodeType {
        try decodeConfig(name: self.rawValue) as DecodeType
    }
}

private func decodeConfig<T: Decodable>(name: String) throws -> T {
    let bundle = Bundle(for: MindboxTests.self)
    guard let fileURL = bundle.url(forResource: name, withExtension: "json") else {
        fatalError("JSON file `\(name)` was not found")
    }
    let data = try Data(contentsOf: fileURL)
    return try JSONDecoder().decode(T.self, from: data)
}
