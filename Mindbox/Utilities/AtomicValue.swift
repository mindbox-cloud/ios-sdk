//
//  AtomicValue.swift
//  Mindbox
//
//  Created by Pavel on 29.06.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

struct AtomicValue<Value> {

    private let queue = DispatchQueue(label: "com.Mindbox.AtomicValue", attributes: .concurrent)
    private var _value: Value

    init(_ value: Value) {
        _value = value
    }

    var value: Value {
        queue.sync { _value }
    }

    mutating func mutate<T>(_ transform: (inout Value) throws -> T) rethrows -> T {
        try queue.sync(flags: .barrier) {
            try transform(&_value)
        }
    }

}
