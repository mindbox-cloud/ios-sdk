//
//  KeyedDecodingContainer+Extensions.swift
//  Mindbox
//
//  Created by vailence on 09.08.2023.
//

import Foundation

extension KeyedDecodingContainer {
    public func decodeIfPresentSafely<T: Decodable>(_ type: T.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> T? {
        do {
            return try decode(T.self, forKey: key)
        } catch DecodingError.typeMismatch, DecodingError.keyNotFound {
            return nil
        }
    }
}
