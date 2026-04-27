//
//  MBConfigurationTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("MBConfiguration", .tags(.mbConfiguration))
struct MBConfigurationTests {

    private let domain = "api.mindbox.ru"
    private let endpoint = "test-endpoint"
    private let validUUID = "F47AC10B-58CC-4372-A567-0E02B2C3D479"

    // MARK: - Init: domain validation

    @Test("Valid domain is accepted")
    func validDomainAccepted() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: domain)
        #expect(config.domain == domain)
    }

    @Test("Empty domain throws")
    func emptyDomainThrows() {
        #expect(throws: MindboxError.self) {
            _ = try MBConfiguration(endpoint: endpoint, domain: "")
        }
    }

    @Test("Domain with whitespace throws")
    func domainWithWhitespaceThrows() {
        #expect(throws: MindboxError.self) {
            _ = try MBConfiguration(endpoint: endpoint, domain: "api mindbox ru")
        }
    }

    @Test("Domain accepts https:// prefix")
    func domainAcceptsHttpsPrefix() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: "https://api.mindbox.ru")
        #expect(config.domain == "https://api.mindbox.ru")
    }

    @Test("Domain accepts http:// prefix")
    func domainAcceptsHttpPrefix() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: "http://proxy.example.com")
        #expect(config.domain == "http://proxy.example.com")
    }

    @Test("Domain accepts trailing slash")
    func domainAcceptsTrailingSlash() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: "api.mindbox.ru/")
        #expect(config.domain == "api.mindbox.ru/")
    }

    @Test("operationsDomain accepts https:// prefix")
    func operationsDomainAcceptsHttpsPrefix() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            operationsDomain: "https://anonymizer.client.ru"
        )
        #expect(config.operationsDomain == "https://anonymizer.client.ru")
    }

    // MARK: - Init: endpoint validation

    @Test("Empty endpoint throws")
    func emptyEndpointThrows() {
        #expect(throws: MindboxError.self) {
            _ = try MBConfiguration(endpoint: "", domain: domain)
        }
    }

    // MARK: - Init: operationsDomain validation

    @Test("nil operationsDomain stored as nil")
    func nilOperationsDomainStoredAsNil() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: domain)
        #expect(config.operationsDomain == nil)
    }

    @Test("Valid operationsDomain stored as-is")
    func validOperationsDomainStored() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            operationsDomain: "anonymizer.client.ru"
        )
        #expect(config.operationsDomain == "anonymizer.client.ru")
    }

    @Test("Empty operationsDomain treated as nil (not throw)")
    func emptyOperationsDomainTreatedAsNil() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            operationsDomain: ""
        )
        #expect(config.operationsDomain == nil)
    }

    @Test("Invalid operationsDomain throws")
    func invalidOperationsDomainThrows() {
        #expect(throws: MindboxError.self) {
            _ = try MBConfiguration(
                endpoint: endpoint,
                domain: domain,
                operationsDomain: "not a host with spaces"
            )
        }
    }

    // MARK: - Init: previousInstallationId / previousDeviceUUID UUID handling

    @Test("Valid previousInstallationId UUID is stored")
    func validPreviousInstallationIdStored() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            previousInstallationId: validUUID
        )
        #expect(config.previousInstallationId == validUUID)
    }

    @Test("Invalid previousInstallationId is silently coerced to empty string")
    func invalidPreviousInstallationIdCoercedToEmpty() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            previousInstallationId: "not-a-uuid"
        )
        #expect(config.previousInstallationId == "")
    }

    @Test("Empty previousInstallationId stays nil")
    func emptyPreviousInstallationIdStaysNil() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            previousInstallationId: ""
        )
        #expect(config.previousInstallationId == nil)
    }

    @Test("Valid previousDeviceUUID is stored")
    func validPreviousDeviceUUIDStored() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            previousDeviceUUID: validUUID
        )
        #expect(config.previousDeviceUUID == validUUID)
    }

    @Test("Invalid previousDeviceUUID is silently coerced to empty string")
    func invalidPreviousDeviceUUIDCoercedToEmpty() throws {
        let config = try MBConfiguration(
            endpoint: endpoint,
            domain: domain,
            previousDeviceUUID: "not-a-uuid"
        )
        #expect(config.previousDeviceUUID == "")
    }

    // MARK: - Init: defaults

    @Test("Default values match documented public API")
    func defaultValues() throws {
        let config = try MBConfiguration(endpoint: endpoint, domain: domain)
        #expect(config.subscribeCustomerIfCreated == false)
        #expect(config.shouldCreateCustomer == true)
        #expect(config.imageLoadingMaxTimeInSeconds == nil)
        #expect(config.previousInstallationId == nil)
        #expect(config.previousDeviceUUID == nil)
        #expect(config.operationsDomain == nil)
    }

    // MARK: - Init: plist

    @Test("Plist init succeeds for valid configurations", .tags(.decoding))
    func plistInitSucceedsForValidConfigs() throws {
        // TestConfig1/2/3 — full valid configurations.
        // TestConfig_Invalid_3/4 — valid despite the filename (only previousIDs / domain
        // edges are checked at the type level, not the file).
        for plist in ["TestConfig1", "TestConfig2", "TestConfig3", "TestConfig_Invalid_3", "TestConfig_Invalid_4"] {
            #expect(throws: Never.self) { try MBConfiguration(plistName: plist) }
        }
    }

    @Test("Plist init throws on empty domain or endpoint", .tags(.decoding))
    func plistInitThrowsOnInvalid() {
        // TestConfig_Invalid_1 — empty domain. TestConfig_Invalid_2 — empty endpoint.
        for plist in ["TestConfig_Invalid_1", "TestConfig_Invalid_2"] {
            #expect(throws: (any Error).self) { try MBConfiguration(plistName: plist) }
        }
    }

    @Test("Plist init throws on missing file")
    func plistInitThrowsOnMissingFile() {
        #expect(throws: (any Error).self) {
            try MBConfiguration(plistName: "definitely-does-not-exist")
        }
    }

    // MARK: - Codable

    @Test("Decodes legacy JSON without operationsDomain key", .tags(.decoding))
    func decodesLegacyJSONWithoutOperationsDomain() throws {
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

    @Test("Decodes JSON with operationsDomain", .tags(.decoding))
    func decodesJSONWithOperationsDomain() throws {
        let json = """
        {
          "endpoint": "app-IOS",
          "domain": "api.mindbox.ru",
          "operationsDomain": "anonymizer.client.ru"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(MBConfiguration.self, from: json)
        #expect(config.operationsDomain == "anonymizer.client.ru")
    }

    @Test("Decoder applies the same validation as the programmatic init", .tags(.decoding))
    func decoderEnforcesValidation() {
        let invalid = """
        { "endpoint": "", "domain": "api.mindbox.ru" }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(MBConfiguration.self, from: invalid)
        }
    }

    // MARK: - ConfigValidation.compare — identity / nil handling

    @Test("Identical configs → none")
    func identicalConfigsReturnNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("Both sides nil → none")
    func bothNilReturnNone() {
        var validation = ConfigValidation()
        validation.compare(nil, nil)
        #expect(validation.changedState == .none)
    }

    @Test("nil vs configured → rest (first init counts as REST change)")
    func nilToConfiguredReturnsRest() throws {
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        var validation = ConfigValidation()
        validation.compare(nil, rhs)
        #expect(validation.changedState == .rest)
    }

    @Test("configured vs nil → rest")
    func configuredToNilReturnsRest() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        var validation = ConfigValidation()
        validation.compare(lhs, nil)
        #expect(validation.changedState == .rest)
    }

    // MARK: - ConfigValidation.compare — REST-affecting fields

    @Test("Domain change → rest")
    func domainChangeReturnsRest() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: "a.mindbox.ru")
        let rhs = try MBConfiguration(endpoint: endpoint, domain: "b.mindbox.ru")
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .rest)
    }

    @Test("Endpoint change → rest")
    func endpointChangeReturnsRest() throws {
        let lhs = try MBConfiguration(endpoint: "endpoint-A", domain: domain)
        let rhs = try MBConfiguration(endpoint: "endpoint-B", domain: domain)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .rest)
    }

    @Test("Domain and endpoint both change → rest (single classification)")
    func bothRestFieldsChangeReturnRest() throws {
        let lhs = try MBConfiguration(endpoint: "endpoint-A", domain: "a.mindbox.ru")
        let rhs = try MBConfiguration(endpoint: "endpoint-B", domain: "b.mindbox.ru")
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .rest)
    }

    // MARK: - ConfigValidation.compare — shouldCreateCustomer

    @Test("shouldCreateCustomer change → shouldCreateCustomer")
    func shouldCreateCustomerChangeReturnsShouldCreateCustomer() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain, shouldCreateCustomer: true)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, shouldCreateCustomer: false)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .shouldCreateCustomer)
    }

    @Test("rest change wins over shouldCreateCustomer change (priority)")
    func restWinsOverShouldCreateCustomer() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: "a.mindbox.ru", shouldCreateCustomer: true)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: "b.mindbox.ru", shouldCreateCustomer: false)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .rest)
    }

    // MARK: - ConfigValidation.compare — fields that must NOT trigger any change

    @Test("operationsDomain change → none (new value applies without re-install)")
    func operationsDomainChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain, operationsDomain: "old.client.ru")
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, operationsDomain: "new.client.ru")
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("subscribeCustomerIfCreated change → none")
    func subscribeCustomerIfCreatedChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain, subscribeCustomerIfCreated: false)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, subscribeCustomerIfCreated: true)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("previousInstallationId change → none")
    func previousInstallationIdChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, previousInstallationId: validUUID)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("previousDeviceUUID change → none")
    func previousDeviceUUIDChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, previousDeviceUUID: validUUID)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("imageLoadingMaxTimeInSeconds change → none")
    func imageLoadingMaxTimeInSecondsChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain, imageLoadingMaxTimeInSeconds: 5)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, imageLoadingMaxTimeInSeconds: 10)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }

    @Test("uuidDebugEnabled change → none")
    func uuidDebugEnabledChangeReturnsNone() throws {
        let lhs = try MBConfiguration(endpoint: endpoint, domain: domain, uuidDebugEnabled: true)
        let rhs = try MBConfiguration(endpoint: endpoint, domain: domain, uuidDebugEnabled: false)
        var validation = ConfigValidation()
        validation.compare(lhs, rhs)
        #expect(validation.changedState == .none)
    }
}
