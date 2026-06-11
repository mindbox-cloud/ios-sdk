//
//  OperationNameValidatorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 11.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

/// Functional contract of the operation-name validator: only ASCII letters,
/// digits, `-` and `.` are allowed, nothing else — including the trailing
/// line terminators the legacy NSRegularExpression check used to let through
/// (ICU `$` matches before a final terminator).
@Suite("OperationNameValidator", .tags(.customOperation))
struct OperationNameValidatorTests {

    @Test("Accepts names made of the documented charset", arguments: [
        "ViewProduct",
        "Website.ProductView",
        "Order.Create.Online",
        "app.event.name-123",
        "TEST.-",
        // single characters from each allowed class
        "a", "z", "A", "Z", "0", "9", "-", ".",
        // the charset imposes no structure - leading/trailing/only separators are fine
        ".op", "-op", "op.", "op-", "...", "---",
        "123",
        String(repeating: "a", count: 256)
    ])
    func accepts(_ name: String) {
        #expect(OperationNameValidator.isValid(name))
    }

    @Test("Rejects anything outside the charset", arguments: [
        "",
        " ",
        "has space",
        "op name",
        "тест",
        "TESт",
        "op_name",
        "emoji😀",
        "op\u{0}name",
        "\nop",
        "op\nname",
        "op\n\n"
    ])
    func rejects(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }

    // ASCII neighbors of the allowed ranges - the exact switch-case boundaries:
    // '@'/'[' surround A-Z, '`'/'{' surround a-z, '/'/':' surround 0-9,
    // ','/'+' sit next to '-' and '.'.
    @Test("Rejects characters adjacent to the allowed ASCII ranges", arguments: [
        "op@", "op[", "op`", "op{", "op/", "op:", "op,", "op+"
    ])
    func rejectsRangeBoundaryNeighbors(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }

    // Unicode traps: lookalikes and invisible characters must not pass.
    @Test("Rejects unicode lookalikes and invisible characters", arguments: [
        "Ｏｐ",            // fullwidth latin (U+FF2F U+FF50)
        "１２３",           // fullwidth digits
        "évent",           // precomposed e-acute
        "e\u{0301}vent",   // combining acute accent
        "op\u{00A0}name",  // no-break space
        "op\tname",        // tab
        "op\u{200B}name"   // zero-width space
    ])
    func rejectsUnicodeLookalikes(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }

    // Intentionally stricter than the legacy regex: a single TRAILING line
    // terminator was accepted by `^...$` (ICU quirk) and such operations were
    // actually sent. The scalar scan enforces the documented charset.
    @Test("Rejects names with a trailing line terminator", arguments: [
        "op\n", "op\r", "op\r\n", "op\u{0085}", "op\u{2028}", "op\u{2029}"
    ])
    func rejectsTrailingLineTerminator(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }
}
