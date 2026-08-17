//
//  LocalStateActionHandlerTests.swift
//  MindboxTests
//
//  Created by Akylbek Utekeshev on 13.08.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@_spi(Internal) @testable import Mindbox

@Suite("LocalStateActionHandler", .tags(.webView))
struct LocalStateActionHandlerTests {

    private func makeSUT() -> (handler: LocalStateActionHandler, storage: LocalStateStorageSpy, host: HostSpy) {
        let storage = LocalStateStorageSpy()
        return (LocalStateActionHandler(makeStorage: { storage }), storage, HostSpy())
    }

    @Test("Owns all three local state actions")
    func ownsLocalStateActions() {
        #expect(LocalStateActionHandler().actions == [.localStateGet, .localStateSet, .localStateInit])
    }

    // MARK: - get

    @Test("Requested keys are read and answered with the stored version")
    func getReadsRequestedKeys() throws {
        let (handler, storage, host) = makeSUT()
        storage.stored = ["seen": "1"]

        handler.handle(.request(.localStateGet, payload: .object(["data": .array([.string("seen")])])), host: host)

        #expect(storage.requestedKeys == ["seen"])
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["data": .object(["seen": .string("1")]), "version": .int(7)]))
    }

    /// The page has to tell "stored as empty" from "never stored", so a miss answers null
    /// rather than being left out of the object.
    @Test("A key that is not stored answers null instead of being omitted")
    func getAnswersNullForMissingKey() throws {
        let (handler, storage, host) = makeSUT()
        storage.stored = ["seen": "1"]

        handler.handle(.request(.localStateGet, payload: .object(["data": .array([.string("seen"), .string("absent")])])),
                       host: host)

        let response = try #require(host.sent.first)
        #expect(response.payload == .object([
            "data": .object(["seen": .string("1"), "absent": .null]),
            "version": .int(7)
        ]))
    }

    @Test("Asking for no keys asks for everything")
    func getWithoutKeysReadsEverything() throws {
        let (handler, storage, host) = makeSUT()
        storage.stored = ["a": "1", "b": "2"]

        handler.handle(.request(.localStateGet, payload: .object(["data": .array([])])), host: host)

        #expect(storage.requestedKeys == [])
        let response = try #require(host.sent.first)
        #expect(response.payload == .object([
            "data": .object(["a": .string("1"), "b": .string("2")]),
            "version": .int(7)
        ]))
    }

    @Test("A payload that is neither a JSON string nor an object is refused")
    func getRefusesMalformedPayload() throws {
        let (handler, _, host) = makeSUT()

        handler.handle(.request(.localStateGet, payload: .string("not json")), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload")]))
    }

    // MARK: - set

    @Test("Values are written and echoed back with the new version")
    func setWritesAndEchoes() throws {
        let (handler, storage, host) = makeSUT()

        handler.handle(.request(.localStateSet, payload: .object(["data": .object(["seen": .string("1")])])), host: host)

        #expect(storage.written?["seen"] == "1")
        let response = try #require(host.sent.first)
        #expect(response.type == .response)
        #expect(response.payload == .object(["data": .object(["seen": .string("1")]), "version": .int(7)]))
    }

    @Test("A null value is an erase and stays distinct from an empty string")
    func setTreatsNullAsErase() throws {
        let (handler, storage, host) = makeSUT()

        handler.handle(.request(.localStateSet, payload: .object(["data": .object(["seen": .null])])), host: host)

        let written = try #require(storage.written)
        #expect(written.keys.contains("seen"))
        #expect(written["seen"] == .some(nil))
        #expect(host.sent.first?.payload == .object(["data": .object(["seen": .null]), "version": .int(7)]))
    }

    /// Storage keeps strings, so a richer value is kept as its JSON text — the page gets back
    /// what it put in instead of losing the key.
    @Test("A non-string value is stored as its JSON text")
    func setEncodesRicherValues() throws {
        let (handler, storage, host) = makeSUT()

        handler.handle(.request(.localStateSet, payload: .object(["data": .object(["count": .int(3)])])), host: host)

        #expect(storage.written?["count"] == "3")
    }

    @Test("A set without a data object is refused")
    func setRefusesMissingData() throws {
        let (handler, storage, host) = makeSUT()

        handler.handle(.request(.localStateSet, payload: .object(["version": .int(1)])), host: host)

        #expect(storage.written == nil)
        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing 'data' object")]))
    }

    // MARK: - init

    @Test("Initialization applies the version and the defaults")
    func initAppliesVersionAndData() throws {
        let (handler, storage, host) = makeSUT()

        handler.handle(.request(.localStateInit, payload: .object([
            "version": .int(3),
            "data": .object(["seen": .string("0")])
        ])), host: host)

        #expect(storage.initializedVersion == 3)
        #expect(storage.written?["seen"] == "0")
        #expect(host.sent.first?.type == .response)
    }

    @Test("A version the storage rejects is reported back rather than swallowed")
    func initReportsRejectedVersion() throws {
        let (handler, storage, host) = makeSUT()
        storage.rejectsInitialize = true

        handler.handle(.request(.localStateInit, payload: .object([
            "version": .int(0),
            "data": .object([:])
        ])), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Version must be a positive integer, got 0")]))
    }

    @Test("An init without a version is refused")
    func initRefusesMissingVersion() throws {
        let (handler, _, host) = makeSUT()

        handler.handle(.request(.localStateInit, payload: .object(["data": .object([:])])), host: host)

        let response = try #require(host.sent.first)
        #expect(response.type == .error)
        #expect(response.payload == .object(["error": .string("Invalid payload: missing 'version' or 'data'")]))
    }

    // MARK: - Envelope

    @Test("A payload sent as a JSON string is understood like a decoded one")
    func acceptsStringifiedPayload() throws {
        let (handler, storage, host) = makeSUT()
        storage.stored = ["seen": "1"]

        handler.handle(.request(.localStateGet, payload: .string("{\"data\":[\"seen\"]}")), host: host)

        #expect(storage.requestedKeys == ["seen"])
        #expect(host.sent.first?.type == .response)
    }

    @Test("Every answer carries the id of the request it answers")
    func answersKeepRequestIdentity() throws {
        let (handler, _, host) = makeSUT()
        let message = BridgeMessage.request(.localStateGet, payload: .object(["data": .array([])]))

        handler.handle(message, host: host)

        #expect(host.sent.first?.id == message.id)
        #expect(host.sent.first?.action == message.action)
    }
}

// MARK: - Doubles

final class LocalStateStorageSpy: WebViewLocalStateStorageProtocol {

    var stored: [String: String] = [:]
    var version = 7
    var rejectsInitialize = false

    private(set) var requestedKeys: [String]?
    private(set) var written: [String: String?]?
    private(set) var initializedVersion: Int?

    func get(keys: [String]) -> WebViewLocalState {
        requestedKeys = keys
        let data = keys.isEmpty ? stored : stored.filter { keys.contains($0.key) }
        return WebViewLocalState(version: version, data: data)
    }

    func set(data: [String: String?]) -> WebViewLocalState {
        written = data
        return WebViewLocalState(version: version, data: stored)
    }

    func initialize(version: Int, data: [String: String?]) -> WebViewLocalState? {
        guard !rejectsInitialize else { return nil }
        initializedVersion = version
        written = data
        return WebViewLocalState(version: version, data: stored)
    }
}
