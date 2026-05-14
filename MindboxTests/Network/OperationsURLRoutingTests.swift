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

        // SDK logs flow through the same `EventRoute.asyncEvent` (see `MBEventRepository.makeRoute`).
        let logsWrapper = Self.makeEventWrapper(.sdkLogs)
        #expect(try builder.asURLRequest(route: EventRoute.asyncEvent(logsWrapper)).url?.host == opsHost)
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
        let logsWrapper = Self.makeEventWrapper(.sdkLogs)

        #expect(try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url?.host == domain)
        #expect(try builder.asURLRequest(route: EventRoute.trackVisit(wrapper)).url?.host == domain)
        #expect(try builder.asURLRequest(route: EventRoute.asyncEvent(logsWrapper)).url?.host == domain)
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

    // MARK: - Scheme handling (host-with-scheme passthrough)

    @Test("Bare host gets default https:// scheme")
    func bareHostUsesHttps() throws {
        let builder = URLRequestBuilder(domain: "api.mindbox.ru")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "api.mindbox.ru")
    }

    @Test("Explicit https:// in domain is preserved")
    func explicitHttpsPreserved() throws {
        let builder = URLRequestBuilder(domain: "https://api.mindbox.ru")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "api.mindbox.ru")
    }

    @Test("Explicit http:// in domain is preserved (proxy/staging case)")
    func explicitHttpPreserved() throws {
        let builder = URLRequestBuilder(domain: "http://proxy.example.com")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "http")
        #expect(url?.host == "proxy.example.com")
    }

    @Test("Bare operationsDomain gets default https:// scheme")
    func bareOperationsDomainUsesHttps() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: "anonymizer.client.ru")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "anonymizer.client.ru")
    }

    @Test("Explicit https:// in operationsDomain is preserved")
    func explicitHttpsInOperationsDomainPreserved() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: "https://anonymizer.client.ru")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "anonymizer.client.ru")
    }

    @Test("Explicit http:// in operationsDomain is preserved (proxy/staging case)")
    func explicitHttpInOperationsDomainPreserved() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: "http://anonymizer-staging.client.ru")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "http")
        #expect(url?.host == "anonymizer-staging.client.ru")
    }

    @Test("Trailing slash in domain is stripped before path append")
    func trailingSlashInDomainStripped() throws {
        let builder = URLRequestBuilder(domain: "api.mindbox.ru/")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.path == "/v3/operations/async")
        #expect(url?.host == "api.mindbox.ru")
    }

    @Test("Trailing slash in operationsDomain is stripped before path append")
    func trailingSlashInOperationsDomainStripped() throws {
        let builder = URLRequestBuilder(domain: domain, operationsDomain: "https://anonymizer.client.ru/")
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "anonymizer.client.ru")
        #expect(url?.path == "/v3/operations/async")
    }

    @Test("Canonical form stored by policy routes correctly end-to-end")
    func canonicalStoredFormRoutesCorrectly() throws {
        // Mirrors what `OperationsDomainConfigPolicy` writes to PersistenceStorage:
        // canonical `scheme://host` form. URLRequestBuilder must accept it as-is.
        let canonical = "https://anonymizer-api-regular.client.ru"
        let builder = URLRequestBuilder(domain: domain, operationsDomain: canonical)
        let wrapper = Self.makeEventWrapper(.installed)

        let url = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper)).url
        #expect(url?.scheme == "https")
        #expect(url?.host == "anonymizer-api-regular.client.ru")
        #expect(url?.path == "/v3/operations/async")
    }

    @Test("Fails fast when base URL is unparseable (no silent relative-URL request)")
    func failsFastOnUnparseableBaseURL() {
        // Embedded space defeats both `URLComponents(string:)` parsing and
        // makes the prior fallback build a bogus relative URL silently.
        let builder = URLRequestBuilder(domain: "bad host with spaces")
        let wrapper = Self.makeEventWrapper(.installed)

        #expect(throws: URLError.self) {
            _ = try builder.asURLRequest(route: EventRoute.asyncEvent(wrapper))
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
        #expect(OperationsDomainConfigPolicy.action(for: "x.ru", currentlyStored: nil) == .save("https://x.ru"))
    }

    @Test("Policy — saves when value changes")
    func policySavesOnChange() {
        #expect(OperationsDomainConfigPolicy.action(for: "new.ru", currentlyStored: "https://old.ru") == .save("https://new.ru"))
    }

    @Test("Policy — keeps when incoming value equals stored")
    func policyKeepsOnIdenticalValue() {
        #expect(OperationsDomainConfigPolicy.action(for: "https://x.ru", currentlyStored: "https://x.ru") == .keep)
    }

    @Test("Policy — clears on null/missing config when something is stored (rollback)")
    func policyClearsOnNullWhenStored() {
        #expect(OperationsDomainConfigPolicy.action(for: nil, currentlyStored: "https://old.ru") == .clear)
    }

    @Test("Policy — clears on empty string when something is stored (rollback)")
    func policyClearsOnEmptyWhenStored() {
        #expect(OperationsDomainConfigPolicy.action(for: "", currentlyStored: "https://old.ru") == .clear)
    }

    @Test("Policy — clears on whitespace-only string when something is stored (Android parity)")
    func policyClearsOnWhitespaceWhenStored() {
        #expect(OperationsDomainConfigPolicy.action(for: "            ", currentlyStored: "https://old.ru") == .clear)
        #expect(OperationsDomainConfigPolicy.action(for: "\t\n  ", currentlyStored: "https://old.ru") == .clear)
    }

    @Test("Policy — no-ops when nothing stored and nothing came")
    func policyKeepsOnNothingToChange() {
        #expect(OperationsDomainConfigPolicy.action(for: nil, currentlyStored: nil) == .keep)
        #expect(OperationsDomainConfigPolicy.action(for: "", currentlyStored: nil) == .keep)
        #expect(OperationsDomainConfigPolicy.action(for: "   ", currentlyStored: nil) == .keep)
    }

    @Test("Policy — trims surrounding whitespace before evaluating value")
    func policyTrimsSurroundingWhitespace() {
        // Trimmed value matches stored after canonicalization → no-op.
        #expect(
            OperationsDomainConfigPolicy.action(for: "  anonymizer.client.ru  ", currentlyStored: "https://anonymizer.client.ru")
                == .keep
        )
        // Trimmed value differs from stored → save canonical form.
        #expect(
            OperationsDomainConfigPolicy.action(for: "  new.client.ru  ", currentlyStored: "https://old.ru")
                == .save("https://new.client.ru")
        )
        // Trimmed value with nothing stored → save canonical form.
        #expect(
            OperationsDomainConfigPolicy.action(for: "  valid.host.ru  ", currentlyStored: nil)
                == .save("https://valid.host.ru")
        )
    }

    @Test("Policy — rejects format-broken incoming value (previous kept intact)")
    func policyRejectsInvalidFormat() {
        #expect(
            OperationsDomainConfigPolicy.action(for: "host with spaces", currentlyStored: "https://good.ru")
                == .rejected("host with spaces")
        )
    }

    @Test("Policy — does NOT spuriously reject when canonical form matches stored (legacy raw)")
    func policyDoesNotRejectOnLegacyRawMatch() {
        // Regression: `.keep` was previously logged as "rejected" whenever raw != stored,
        // even when raw was valid and just normalized to the stored form.
        #expect(
            OperationsDomainConfigPolicy.action(for: "x.ru", currentlyStored: "https://x.ru")
                == .keep
        )
    }

    @Test("Policy — normalizes scheme + trailing slash to canonical form")
    func policyNormalizesSchemeAndTrailingSlash() {
        #expect(
            OperationsDomainConfigPolicy.action(
                for: "https://anonymizer-api-regular.client.ru/",
                currentlyStored: nil
            ) == .save("https://anonymizer-api-regular.client.ru")
        )
    }

    @Test("Policy — preserves http scheme from config (does not force https)")
    func policyPreservesHttpScheme() {
        #expect(
            OperationsDomainConfigPolicy.action(for: "http://x.ru/", currentlyStored: nil)
                == .save("http://x.ru")
        )
    }

    @Test("Policy — keeps when canonical form equals stored despite raw differences")
    func policyKeepsWhenCanonicalFormMatches() {
        #expect(
            OperationsDomainConfigPolicy.action(
                for: "https://x.ru/",
                currentlyStored: "https://x.ru"
            ) == .keep
        )
    }

    @Test("Policy — upgrade path: legacy bare-host stored value re-saves once as canonical")
    func policyUpgradesLegacyStoredValue() {
        #expect(
            OperationsDomainConfigPolicy.action(for: "x.ru", currentlyStored: "x.ru")
                == .save("https://x.ru")
        )
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

    // MARK: - Helpers

    private static func makeEventWrapper(
        _ type: Event.Operation,
        bodyJSON: String = "{}"
    ) -> EventWrapper {
        let event = Event(type: type, body: bodyJSON)
        return EventWrapper(event: event, endpoint: "test-endpoint", deviceUUID: "F47AC10B-58CC-4372-A567-0E02B2C3D479")
    }
}
