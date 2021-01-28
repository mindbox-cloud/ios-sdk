//
//  File.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

@propertyWrapper
struct Injected<Value> {
    private(set) var wrappedValue: Value

    init() {
        guard let value: Value = resolver.resolve() else {
            fatalError("Could not resolve non-optional \(Value.self)")
        }

        wrappedValue = value
    }

}

@propertyWrapper
struct InjectedOptional<Value> {
    private(set) var wrappedValue: Optional<Value>

    init() {
        guard let value: Value = resolver.resolve() else {
            fatalError("Could not resolve non-optional \(Value.self)")
        }

        wrappedValue = value
    }
}
