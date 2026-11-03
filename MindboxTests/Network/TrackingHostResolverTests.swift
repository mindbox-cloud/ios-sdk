//
//  TrackingHostResolverTests.swift
//  MindboxTests
//
//  Created by Sergei Semko on 03.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import Testing
@testable import Mindbox

@Suite("Tracking host resolver", .tags(.trackingIds))
struct TrackingHostResolverTests {

    private func makeResolver(
        domain: String? = "api.mindbox.ru",
        operationsDomain: String? = nil,
        operationsDomainFromConfig: String? = nil,
        declaredDomains: Set<String> = ["api-tracking.mindbox.ru"],
        misconfigurationHandler: @escaping (String) -> Void = { Issue.record("Unexpected misconfiguration report: \($0)") }
    ) throws -> TrackingHostResolver {
        let storage = MockPersistenceStorage()
        if let domain {
            storage.configuration = try MBConfiguration(endpoint: "e", domain: domain, operationsDomain: operationsDomain)
        }
        storage.operationsDomainFromConfig = operationsDomainFromConfig
        return TrackingHostResolver(persistenceStorage: storage,
                                    declaredTrackingDomains: declaredDomains,
                                    misconfigurationHandler: misconfigurationHandler)
    }

    @Test("Derivation: api → api-tracking, api-staging → api-tracking-staging, any zone")
    func derivationInsertsTheTrackingLabel() {
        #expect(TrackingHostResolver.deriveTrackingHost(from: "api.mindbox.ru") == "api-tracking.mindbox.ru")
        #expect(TrackingHostResolver.deriveTrackingHost(from: "api-staging.mindbox.ru") == "api-tracking-staging.mindbox.ru")
        #expect(TrackingHostResolver.deriveTrackingHost(from: "api.maestra.io") == "api-tracking.maestra.io")
        #expect(TrackingHostResolver.deriveTrackingHost(from: "mobile-sdk-test.mindbox.ru") == nil)
    }

    @Test("A declared derived host is the tracking host")
    func declaredDerivedHostIsTheTrackingHost() throws {
        let resolver = try makeResolver()
        #expect(resolver.trackingHost == "api-tracking.mindbox.ru")
    }

    @Test("The configured domain's case is ignored when deriving the tracking host")
    func configuredDomainCaseIsIgnored() throws {
        let resolver = try makeResolver(domain: "API.Mindbox.ru", declaredDomains: ["api-tracking.mindbox.ru"])
        #expect(resolver.trackingHost == "api-tracking.mindbox.ru")
    }

    @Test("An undeclared host gives nil")
    func undeclaredHostGivesNil() throws {
        let resolver = try makeResolver(declaredDomains: ["api-tracking-staging.mindbox.ru"])
        #expect(resolver.trackingHost == nil)
    }

    @Test("No configuration gives nil")
    func noConfigurationGivesNil() throws {
        let resolver = try makeResolver(domain: nil)
        #expect(resolver.trackingHost == nil)
    }

    @Test("An operationsDomain from init or from the config gives nil")
    func operationsDomainGivesNil() throws {
        let fromInit = try makeResolver(operationsDomain: "proxy.client.ru")
        #expect(fromInit.trackingHost == nil)

        let fromConfig = try makeResolver(operationsDomainFromConfig: "proxy.client.ru")
        #expect(fromConfig.trackingHost == nil)
    }

    @Test("A missing tracking host names its reason")
    func missingTrackingHostNamesItsReason() throws {
        #expect(try makeResolver().resolution == .available("api-tracking.mindbox.ru"))
        #expect(try makeResolver(domain: nil).resolution == .notInitialized)
        #expect(try makeResolver(operationsDomain: "proxy.client.ru").resolution == .operationsDomain("proxy.client.ru"))
        #expect(try makeResolver(operationsDomainFromConfig: "proxy.client.ru").resolution == .operationsDomain("proxy.client.ru"))
        #expect(try makeResolver(domain: "mobile-sdk-test.mindbox.ru").resolution == .notDerivable(mainHost: "mobile-sdk-test.mindbox.ru"))
        #expect(try makeResolver(declaredDomains: []).resolution == .notDeclared("api-tracking.mindbox.ru"))
    }

    @Test("The main host or a parent domain declared as tracking gives nil and is reported once")
    func mainHostOrParentDeclaredAsTrackingIsReportedOnce() throws {
        var reports: [String] = []
        let resolver = try makeResolver(declaredDomains: ["api.mindbox.ru"]) { reports.append($0) }

        #expect(resolver.trackingHost == nil)
        #expect(reports.isEmpty)
        resolver.reportIfMainHostIsDeclaredAsTracking()
        resolver.reportIfMainHostIsDeclaredAsTracking()
        #expect(reports.count == 1)
        #expect(reports.first?.contains("api.mindbox.ru") == true)

        var parentReports: [String] = []
        let parent = try makeResolver(declaredDomains: ["mindbox.ru"]) { parentReports.append($0) }
        #expect(parent.trackingHost == nil)
        parent.reportIfMainHostIsDeclaredAsTracking()
        #expect(parentReports.count == 1)
    }

    @Test("Manifest parsing: tracking true lists the domains lowercased, tracking false or missing lists nothing")
    func manifestParsing() {
        func manifest(tracking: String?, domains: [String]) -> Data {
            let trackingKey = tracking.map { "<key>NSPrivacyTracking</key><\($0)/>" } ?? ""
            let domainsXML = domains.map { "<string>\($0)</string>" }.joined()
            return Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>\(trackingKey)<key>NSPrivacyTrackingDomains</key><array>\(domainsXML)</array></dict></plist>
            """.utf8)
        }

        let declared = TrackingHostResolver.declaredTrackingDomains(manifest: manifest(tracking: "true", domains: ["API-Tracking.Mindbox.ru", "api-tracking-staging.mindbox.ru"]))
        #expect(declared == ["api-tracking.mindbox.ru", "api-tracking-staging.mindbox.ru"])

        #expect(TrackingHostResolver.declaredTrackingDomains(manifest: manifest(tracking: "false", domains: ["api-tracking.mindbox.ru"])) == [])
        #expect(TrackingHostResolver.declaredTrackingDomains(manifest: manifest(tracking: nil, domains: ["api-tracking.mindbox.ru"])) == [])
        #expect(TrackingHostResolver.declaredTrackingDomains(manifest: Data("not a plist".utf8)) == [])
    }

    @Test("A bundle without a privacy manifest declares nothing")
    func bundleWithoutManifestDeclaresNothing() {
        #expect(TrackingHostResolver.declaredTrackingDomains(in: Bundle(for: MockPersistenceStorage.self)) == [])
    }
}
