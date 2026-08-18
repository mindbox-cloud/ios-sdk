//
//  Locked.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// A stored property whose reads and writes are individually atomic. A compound mutation through
/// `wrappedValue` is a locked read then a locked write, so it can still lose a concurrent update —
/// use ``mutate(_:)`` for that. The lock is never held while calling out: property observers run
/// after the store.
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

    /// Reads, mutates and stores under one lock, so `insert`, `append` and friends cannot lose a
    /// concurrent update the way `wrappedValue` mutation can.
    ///
    /// - Warning: the lock is held for the whole body. Do not call back into the same wrapper or
    ///   block inside it.
    @discardableResult
    public func mutate<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
