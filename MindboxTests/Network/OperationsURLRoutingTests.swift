//
//  OperationsURLRoutingTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Operations URL routing", .tags(.operationsRouting))
struct OperationsURLRoutingTests {

    private let domain = "api.mindbox.ru"
    private let opsHost = "anonymizer-api-regular.client.ru"

    // MARK: - URLRequestBuilder host resolution

    @Test("Event routes use operationsDomain when configured")
    func eventRoutesUseOperationsDomain() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: opsHost)
        let wrapper = Self.makeEventWrapper(.installed)

        #expect(try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url?.host == opsHost)
        #expect(try builder.asURLRequest(route: EventRoute.customAsyncEvent(wrapper)).url?.host == opsHost)
        #expect(try builder.asURLRequest(route: EventRoute.trackVisit(wrapper)).url?.host == opsHost)

        let syncWrapper = Self.makeEventWrapper(.syncEvent, bodyJSON: #"{"name":"X","payload":"{}"}"#)
        #expect(try builder.asURLRequest(route: EventRoute.syncEvent(syncWrapper)).url?.host == opsHost)
    }

    @Test("SDKLogsRoute uses operationsDomain when configured")
    func sdkLogsRouteUsesOperationsDomain() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: opsHost)
        let url = try builder.asURLRequest(route: SDKLogsRoute()).url
        #expect(url?.host == opsHost)
    }

    @Test("Config and geo routes always use domain")
    func domainRoutesIgnoreOperationsDomain() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: opsHost)

        let geoURL = try builder.asURLRequest(route: FetchInAppGeoRoute()).url
        #expect(geoURL?.host == domain)
        #expect(geoURL?.path == "/geo")
    }

    @Test("No operationsDomain → all routes fall back to domain (backwards compatibility)")
    func noOperationsDomainFallsBackToDomain() throws {
        let builder = URLRequestBuilder(domain: domain)
        let wrapper = Self.makeEventWrapper(.installed)

        #expect(try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url?.host == domain)
        #expect(try builder.asURLRequest(route: EventRoute.trackVisit(wrapper)).url?.host == domain)
        #expect(try builder.asURLRequest(route: SDKLogsRoute()).url?.host == domain)
        #expect(try builder.asURLRequest(route: FetchInAppGeoRoute()).url?.host == domain)
    }

    @Test("Path and query parameters survive host swap")
    func pathAndQueryUnchangedOnHostSwap() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: opsHost)
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.path == "/v3/operations/async")
        #expect(url?.query?.contains("operation=MobilePush.ApplicationInstalled") == true)
        #expect(url?.query?.contains("endpointId=test-endpoint") == true)
    }

    // MARK: - MBConfiguration validation

    @Test("MBConfiguration accepts nil operationsDomain (backwards compatible)")
    func configAcceptsNilOperationsDomain() throws {
        let config = try MBConfiguration(endpoint: "e", domain: domain)
        #expect(config.operationsDomain == nil)
    }

    @Test("MBConfiguration accepts valid operationsDomain")
    func configAcceptsValidOperationsDomain() throws {
        let config = try MBConfiguration(
            endpoint: "e",
            domain: domain,
            operationsDomain: opsHost
        )
        #expect(config.operationsDomain == opsHost)
    }

    @Test("MBConfiguration treats empty operationsDomain as nil")
    func configTreatsEmptyOperationsDomainAsNil() throws {
        let config = try MBConfiguration(
            endpoint: "e",
            domain: domain,
            operationsDomain: ""
        )
        #expect(config.operationsDomain == nil)
    }

    @Test("MBConfiguration rejects invalid operationsDomain")
    func configRejectsInvalidOperationsDomain() {
        #expect(throws: MindboxError.self) {
            _ = try MBConfiguration(
                endpoint: "e",
                domain: domain,
                operationsDomain: "not a host with spaces"
            )
        }
    }

    // MARK: - Rollback signals from JSON config
    //
    // Happy-path and key/type errors live in `SettingsConfigParsingTests`
    // (driven by the canonical `pkl-mobile-config` stubs). The two cases
    // below stay here because they exercise the rollback channel that's
    // specific to this feature and not modeled in the Pkl error stubs.

    @Test("Settings decodes explicit null as rollback signal", .tags(.decoding))
    func settingsDecodesNullOperationsAsRollback() throws {
        let json = """
        { "settings": { "baseAddresses": { "operations": null } } }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ConfigResponse.self, from: json)
        #expect(response.settings?.baseAddresses != nil)
        #expect(response.settings?.baseAddresses?.operations == nil)
    }

    @Test("Settings decodes empty string as rollback signal", .tags(.decoding))
    func settingsDecodesEmptyOperationsAsRollback() throws {
        let json = """
        { "settings": { "baseAddresses": { "operations": "" } } }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ConfigResponse.self, from: json)
        #expect(response.settings?.baseAddresses?.operations == "")
    }

    // MARK: - ConfigValidation.compare

    @Test("ConfigValidation does NOT flag operationsDomain change — new value applies without re-install")
    func configValidationIgnoresOperationsDomainChange() throws {
        let lhs = try MBConfiguration(
            endpoint: "e",
            domain: domain,
            operationsDomain: "old.client.ru"
        )
        let rhs = try MBConfiguration(
            endpoint: "e",
            domain: domain,
            operationsDomain: "new.client.ru"
        )
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("ConfigValidation still flags domain change as REST (operationsDomain unaffected)")
    func configValidationDetectsDomainChange() throws {
        let lhs = try MBConfiguration(endpoint: "e", domain: "a.mindbox.ru",
                                      operationsDomain: opsHost)
        let rhs = try MBConfiguration(endpoint: "e", domain: "b.mindbox.ru",
                                      operationsDomain: opsHost)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .rest)
    }

    // MARK: - Priority resolution (MBNetworkFetcher)

    @Test("Priority — JSON wins when both JSON and init are set")
    func priorityJSONWinsOverInit() {
        let resolved = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: "json.example.ru",
            fromInit: "init.example.ru"
        )
        #expect(resolved == "json.example.ru")
    }

    @Test("Priority — init used when JSON has nothing")
    func priorityInitUsedWhenJSONMissing() {
        let resolved = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: nil,
            fromInit: "init.example.ru"
        )
        #expect(resolved == "init.example.ru")
    }

    @Test("Priority — returns nil (→ domain fallback) when neither set")
    func priorityNilWhenNeitherSet() {
        let resolved = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: nil,
            fromInit: nil
        )
        #expect(resolved == nil)
    }

    @Test("Priority — empty-string JSON treated as no value, falls through to init")
    func priorityEmptyStringJSONFallsThrough() {
        let resolved = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: "",
            fromInit: "init.example.ru"
        )
        #expect(resolved == "init.example.ru")
    }

    @Test("Priority — empty-string init also treated as no value")
    func priorityEmptyStringInitFallsThrough() {
        let resolved = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: nil,
            fromInit: ""
        )
        #expect(resolved == nil)
    }

    // MARK: - OperationsDomainConfigPolicy (decides save / clear / keep from JSON)

    @Test("Policy — saves a new valid value when storage is empty")
    func policySavesNewValueFromEmpty() {
        #expect(OperationsDomainConfigPolicy.action(for: "x.ru", currentlyStored: nil) == .save("x.ru"))
    }

    @Test("Policy — saves when value changes")
    func policySavesOnChange() {
        #expect(OperationsDomainConfigPolicy.action(for: "new.ru", currentlyStored: "old.ru") == .save("new.ru"))
    }

    @Test("Policy — keeps when incoming value equals stored")
    func policyKeepsOnIdenticalValue() {
        #expect(OperationsDomainConfigPolicy.action(for: "x.ru", currentlyStored: "x.ru") == .keep)
    }

    @Test("Policy — clears on null/missing config when something is stored")
    func policyClearsOnNullWhenStored() {
        #expect(OperationsDomainConfigPolicy.action(for: nil, currentlyStored: "old.ru") == .clear)
    }

    @Test("Policy — clears on empty string when something is stored")
    func policyClearsOnEmptyWhenStored() {
        #expect(OperationsDomainConfigPolicy.action(for: "", currentlyStored: "old.ru") == .clear)
    }

    @Test("Policy — no-ops when nothing stored and nothing came")
    func policyKeepsOnNothingToChange() {
        #expect(OperationsDomainConfigPolicy.action(for: nil, currentlyStored: nil) == .keep)
        #expect(OperationsDomainConfigPolicy.action(for: "", currentlyStored: nil) == .keep)
    }

    @Test("Policy — preserves previous value when incoming host is format-broken")
    func policyKeepsOnInvalidFormat() {
        #expect(OperationsDomainConfigPolicy.action(for: "host with spaces", currentlyStored: "good.ru") == .keep)
    }

    // MARK: - Persistence lifecycle

    @Test("softReset preserves operationsDomainFromConfig (no PD leak on migration reset)")
    func softResetPreservesOperationsDomain() {
        let storage = MockPersistenceStorage()
        storage.operationsDomainFromConfig = "cached-anonymizer.ru"
        storage.configDownloadDate = Date()

        storage.softReset()

        #expect(storage.operationsDomainFromConfig == "cached-anonymizer.ru")
        #expect(storage.configDownloadDate == nil)
    }

    @Test("reset clears operationsDomainFromConfig (test-only hard reset)")
    func hardResetClearsOperationsDomain() {
        let storage = MockPersistenceStorage()
        storage.operationsDomainFromConfig = "cached.ru"

        storage.reset()

        #expect(storage.operationsDomainFromConfig == nil)
    }

    // MARK: - Backwards compatibility

    @Test("MBConfiguration decodes legacy JSON without operationsDomain key", .tags(.decoding))
    func decodesLegacyConfigWithoutOperationsDomain() throws {
        let legacyJSON = """
        {
          "endpoint": "app-IOS",
          "domain": "api.mindbox.ru",
          "subscribeCustomerIfCreated": false,
          "shouldCreateCustomer": true,
          "uuidDebugEnabled": true
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(MBConfiguration.self, from: legacyJSON)
        #expect(config.endpoint == "app-IOS")
        #expect(config.domain == "api.mindbox.ru")
        #expect(config.operationsDomain == nil)
    }

    // MARK: - Helpers

    private static func makeEventWrapper(
        _ type: Event.Operation,
        bodyJSON: String = "{}"
    ) -> EventWrapper {
        let event = Event(type: type, body: bodyJSON)
        return EventWrapper(event: event, endpoint: "test-endpoint", deviceUUID: "F47AC10B-58CC-4372-A567-0E02B2C3D479")
    }
}
