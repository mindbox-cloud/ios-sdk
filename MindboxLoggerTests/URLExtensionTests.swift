//
//  URLExtensionTests.swift
//  MindboxLoggerTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
@testable import MindboxLogger

@Suite("URL file attributes", .tags(.storage))
struct URLExtensionTests {

    @Test("fileSize and attributes reflect an existing file")
    func existingFile() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mb-url-\(UUID().uuidString).bin")
        try Data(repeating: 0xAB, count: 1234).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.fileSize == 1234)
        let attributes = try #require(url.attributes)
        #expect(attributes[.size] != nil)
    }

    @Test("fileSize is zero and attributes nil for a missing file")
    func missingFile() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mb-missing-\(UUID().uuidString).bin")
        #expect(url.fileSize == 0)
        #expect(url.attributes == nil)
    }
}
