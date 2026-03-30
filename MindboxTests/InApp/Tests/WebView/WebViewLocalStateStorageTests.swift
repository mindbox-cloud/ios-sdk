//
//  WebViewLocalStateStorageTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 3/11/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
@testable import Mindbox

@Suite("WebViewLocalStateStorage", .tags(.webView))
struct WebViewLocalStateStorageTests {

    private let testSuiteName = "cloud.Mindbox.test.webview.localState"
    private let keyPrefix = Constants.WebViewLocalState.keyPrefix

    private func makeSUT() -> (sut: WebViewLocalStateStorage, defaults: UserDefaults, persistence: MockPersistenceStorage) {
        let persistence = MockPersistenceStorage()
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.removePersistentDomain(forName: testSuiteName)
        let sut = WebViewLocalStateStorage(dataDefaults: defaults, persistenceStorage: persistence)
        return (sut, defaults, persistence)
    }

    // MARK: - get

    @Test("get returns default version and empty data when storage is empty")
    func getEmptyStorage() {
        let (sut, _, _) = makeSUT()

        let state = sut.get(keys: [])

        #expect(state.version == Constants.WebViewLocalState.defaultVersion)
        #expect(state.data.isEmpty)
    }

    @Test("get returns all stored keys when keys array is empty")
    func getAllKeys() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("value1", forKey: "\(keyPrefix)key1")
        defaults.set("value2", forKey: "\(keyPrefix)key2")

        let state = sut.get(keys: [])

        #expect(state.data.count == 2)
        #expect(state.data["key1"] == "value1")
        #expect(state.data["key2"] == "value2")
    }

    @Test("get returns only requested keys")
    func getSpecificKeys() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("value1", forKey: "\(keyPrefix)key1")
        defaults.set("value2", forKey: "\(keyPrefix)key2")
        defaults.set("value3", forKey: "\(keyPrefix)key3")

        let state = sut.get(keys: ["key1", "key3"])

        #expect(state.data.count == 2)
        #expect(state.data["key1"] == "value1")
        #expect(state.data["key3"] == "value3")
    }

    @Test("get returns only found keys, missing keys are absent")
    func getMissingKeys() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("value1", forKey: "\(keyPrefix)key1")

        let state = sut.get(keys: ["key1", "missing"])

        #expect(state.data.count == 1)
        #expect(state.data["key1"] == "value1")
        #expect(state.data["missing"] == nil)
    }

    @Test("get returns current version from persistence")
    func getCurrentVersion() {
        let (sut, _, persistence) = makeSUT()
        persistence.webViewLocalStateVersion = 5

        let state = sut.get(keys: [])

        #expect(state.version == 5)
    }

    @Test("get returns default version when persistence version is nil")
    func getDefaultVersion() {
        let (sut, _, persistence) = makeSUT()
        persistence.webViewLocalStateVersion = nil

        let state = sut.get(keys: [])

        #expect(state.version == Constants.WebViewLocalState.defaultVersion)
    }

    // MARK: - set

    @Test("set stores values in UserDefaults")
    func setStoresValues() {
        let (sut, defaults, _) = makeSUT()

        _ = sut.set(data: ["key1": "value1", "key2": "value2"])

        #expect(defaults.string(forKey: "\(keyPrefix)key1") == "value1")
        #expect(defaults.string(forKey: "\(keyPrefix)key2") == "value2")
    }

    @Test("set removes key when value is nil")
    func setRemovesNilKey() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("value1", forKey: "\(keyPrefix)key1")

        _ = sut.set(data: ["key1": nil])

        #expect(defaults.string(forKey: "\(keyPrefix)key1") == nil)
    }

    @Test("set updates existing values")
    func setUpdatesValues() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("old", forKey: "\(keyPrefix)key1")

        let state = sut.set(data: ["key1": "new"])

        #expect(defaults.string(forKey: "\(keyPrefix)key1") == "new")
        #expect(state.data["key1"] == "new")
    }

    @Test("set returns only affected keys")
    func setReturnsAffectedKeys() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("existing", forKey: "\(keyPrefix)existing")

        let state = sut.set(data: ["key1": "value1"])

        #expect(state.data.count == 1)
        #expect(state.data["key1"] == "value1")
        #expect(state.data["existing"] == nil)
    }

    @Test("set does not change version")
    func setPreservesVersion() {
        let (sut, _, persistence) = makeSUT()
        persistence.webViewLocalStateVersion = 3

        let state = sut.set(data: ["key1": "value1"])

        #expect(state.version == 3)
        #expect(persistence.webViewLocalStateVersion == 3)
    }

    @Test("set stores each key as separate UserDefaults entry")
    func setSeparateEntries() {
        let (sut, defaults, _) = makeSUT()

        _ = sut.set(data: ["firstKey": "firstValue", "secondKey": "secondValue"])

        #expect(defaults.string(forKey: "\(keyPrefix)firstKey") == "firstValue")
        #expect(defaults.string(forKey: "\(keyPrefix)secondKey") == "secondValue")
    }

    // MARK: - initialize

    @Test("initialize stores version in PersistenceStorage")
    func initStoresVersion() {
        let (sut, _, persistence) = makeSUT()

        _ = sut.initialize(version: 7, data: ["key": "value"])

        #expect(persistence.webViewLocalStateVersion == 7)
    }

    @Test("initialize stores data and returns it")
    func initStoresAndReturnsData() throws {
        let (sut, defaults, _) = makeSUT()

        let state = try #require(sut.initialize(version: 2, data: ["key1": "value1", "key2": "value2"]))

        #expect(state.version == 2)
        #expect(state.data["key1"] == "value1")
        #expect(state.data["key2"] == "value2")
        #expect(defaults.string(forKey: "\(keyPrefix)key1") == "value1")
        #expect(defaults.string(forKey: "\(keyPrefix)key2") == "value2")
    }

    @Test("initialize rejects zero version")
    func initRejectsZero() {
        let (sut, _, _) = makeSUT()

        #expect(sut.initialize(version: 0, data: ["key": "value"]) == nil)
    }

    @Test("initialize rejects negative version")
    func initRejectsNegative() {
        let (sut, _, _) = makeSUT()

        #expect(sut.initialize(version: -1, data: ["key": "value"]) == nil)
    }

    @Test("initialize removes keys with nil values")
    func initRemovesNilKeys() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("value1", forKey: "\(keyPrefix)key1")

        let state = sut.initialize(version: 2, data: ["key1": nil])

        #expect(state != nil)
        #expect(defaults.string(forKey: "\(keyPrefix)key1") == nil)
    }

    @Test("initialize merges with existing data")
    func initMergesData() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("existing", forKey: "\(keyPrefix)old")

        let state = sut.initialize(version: 3, data: ["new": "value"])

        #expect(state != nil)
        #expect(defaults.string(forKey: "\(keyPrefix)old") == "existing")
        #expect(defaults.string(forKey: "\(keyPrefix)new") == "value")
    }

    @Test("initialize does not store version on rejection")
    func initPreservesVersionOnReject() {
        let (sut, _, persistence) = makeSUT()
        persistence.webViewLocalStateVersion = 5

        _ = sut.initialize(version: 0, data: ["key": "value"])

        #expect(persistence.webViewLocalStateVersion == 5)
    }

    // MARK: - Integration

    @Test("full flow: init → set → get")
    func fullFlow() throws {
        let (sut, _, _) = makeSUT()

        let initState = try #require(sut.initialize(version: 2, data: ["key1": "value1", "key2": "value2"]))
        #expect(initState.version == 2)

        let setState = sut.set(data: ["key1": "updated", "key2": nil, "key3": "value3"])
        #expect(setState.version == 2)

        let getState = sut.get(keys: [])
        #expect(getState.version == 2)
        #expect(getState.data["key1"] == "updated")
        #expect(getState.data["key2"] == nil)
        #expect(getState.data["key3"] == "value3")
    }

    @Test("get returns no data for deleted key")
    func setNullThenGet() {
        let (sut, _, _) = makeSUT()

        _ = sut.set(data: ["key1": "value1"])
        _ = sut.set(data: ["key1": nil])

        let state = sut.get(keys: ["key1"])
        #expect(state.data.isEmpty)
    }

    @Test("prefix isolation: non-prefixed keys and Apple system keys are filtered out")
    func prefixIsolation() {
        let (sut, defaults, _) = makeSUT()
        defaults.set("foreign", forKey: "foreignKey")
        defaults.set("value", forKey: "\(keyPrefix)myKey")

        let state = sut.get(keys: [])

        #expect(state.data.count == 1)
        #expect(state.data["myKey"] == "value")
        #expect(state.data["foreignKey"] == nil)
        #expect(state.data["AKLastLocale"] == nil)
        #expect(state.data["AppleLocale"] == nil)
        #expect(state.data["NSInterfaceStyle"] == nil)
    }
}
