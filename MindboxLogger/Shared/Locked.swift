//
//  Locked.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// A stored property whose reads and writes are individually atomic.
///
/// This is memory safety, not transactionality: a compound mutation (`append`, `insert`, `+=`)
/// is a locked read followed by a locked write, so properties that need read-modify-write
/// atomicity across threads still need one writer or a lock of their own. The SDK's shared
/// state is almost all single-writer-many-readers, which is exactly the shape this covers.
///
/// The lock is never held while calling out: `willSet`/`didSet` observers on the wrapped
/// property run after the store completes, so an observer that touches another `@Locked`
/// property cannot deadlock.
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
}
