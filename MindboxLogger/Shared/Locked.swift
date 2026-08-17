//
//  Locked.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// A stored property whose reads and writes are individually atomic — not transactional: a compound
/// mutation is a locked read then a locked write, so cross-thread read-modify-write still needs a
/// single writer. The lock is never held while calling out: property observers run after the store.
@propertyWrapper
public final class Locked<Value> {

    private let lock = NSLock()
    private var value: Value

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }

    public var projectedValue: Locked<Value> { self }

    /// Atomically replaces the value and returns what it replaced — the one compound mutation a
    /// read-then-write through `wrappedValue` cannot make race-free.
    public func exchange(_ newValue: Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        let oldValue = value
        value = newValue
        return oldValue
    }
}
