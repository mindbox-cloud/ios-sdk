//
//  Tag+Extensions.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing

extension Tag {
    /// Date / time-interval formatting helpers.
    @Tag static var dateFormatting: Self
    /// The logging facade itself: `Logger` / `MBLogger` entry points, `OSLogWriter`,
    /// log levels, categories and `LogMessage` rendering.
    @Tag static var loggingAPI: Self
    /// Error & decodable model types: `MindboxError`, `ProtocolError`,
    /// `ValidationError`, `LoggerErrorModel`, `UnknownDecodable`, `Status`.
    @Tag static var errorHandling: Self
    /// Core Data persistence stack: the CRUD manager, database loader, persistent
    /// container, SQLite size measurer, context helper and store-URL resolution.
    @Tag static var storage: Self
    /// Enable / disable & graceful-degradation behaviour: bootstrap state,
    /// App Group fallback, and storage-state introspection.
    @Tag static var storageState: Self
    /// Log retention / size-limit trimming policy.
    @Tag static var trimming: Self
}
