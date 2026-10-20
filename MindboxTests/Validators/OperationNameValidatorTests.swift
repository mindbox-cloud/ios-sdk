//
//  OperationNameValidatorTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 11.06.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("OperationNameValidator", .tags(.customOperation))
struct OperationNameValidatorTests {

    @Test("Accepts names made of the documented charset", arguments: [
        "ViewProduct",
        "Website.ProductView",
        "Order.Create.Online",
        "app.event.name-123",
        "TEST.-",
        "a", "z", "A", "Z", "0", "9", "-", ".",
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

    @Test("Rejects characters adjacent to the allowed ASCII ranges", arguments: [
        "op@", "op[", "op`", "op{", "op/", "op:", "op,", "op+"
    ])
    func rejectsRangeBoundaryNeighbors(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }

    @Test("Rejects unicode lookalikes and invisible characters", arguments: [
        "Ｏｐ",
        "１２３",
        "évent",
        "e\u{0301}vent",
        "op\u{00A0}name",
        "op\tname",
        "op\u{200B}name"
    ])
    func rejectsUnicodeLookalikes(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }

    @Test("Rejects names with a trailing line terminator", arguments: [
        "op\n", "op\r", "op\r\n", "op\u{0085}", "op\u{2028}", "op\u{2029}"
    ])
    func rejectsTrailingLineTerminator(_ name: String) {
        #expect(!OperationNameValidator.isValid(name))
    }
}
