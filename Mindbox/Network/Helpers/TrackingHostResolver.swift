//
//  TrackingHostResolver.swift
//  Mindbox
//
//  Created by Sergei Semko on 02.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum TrackingHostResolution: Equatable {
    case available(String)
    case notInitialized
    case operationsDomain(String)
    case notDerivable(mainHost: String)
    case notDeclared(String)

    var host: String? {
        guard case let .available(host) = self else { return nil }
        return host
    }

    var unavailableReason: String? {
        switch self {
        case .available: return nil
        case .notInitialized: return "the SDK is not initialized"
        case let .operationsDomain(domain): return "operations go through operationsDomain \(domain)"
        case let .notDerivable(mainHost): return "no tracking host can be derived from \(mainHost)"
        case let .notDeclared(host): return "the app's privacy manifest does not list \(host)"
        }
    }
}

final class TrackingHostResolver {
    private let persistenceStorage: PersistenceStorage
    private let declaredTrackingDomains: Set<String>
    private let misconfigurationHandler: (String) -> Void
    @Locked private var hasReportedMainHostDeclared = false

    init(persistenceStorage: PersistenceStorage,
         declaredTrackingDomains: Set<String>,
         misconfigurationHandler: @escaping (String) -> Void = { assertionFailure($0) }) {
        self.persistenceStorage = persistenceStorage
        self.declaredTrackingDomains = declaredTrackingDomains
        self.misconfigurationHandler = misconfigurationHandler
    }

    var trackingHost: String? {
        resolution.host
    }

    var resolution: TrackingHostResolution {
        guard let configuration = persistenceStorage.configuration else { return .notInitialized }
        if let operationsDomain = MBNetworkFetcher.resolveOperationsDomain(
            fromConfigJSON: persistenceStorage.operationsDomainFromConfig,
            fromInit: configuration.operationsDomain
        ) {
            return .operationsDomain(operationsDomain)
        }
        let mainHost = Self.mainHost(of: configuration)
        guard let host = Self.deriveTrackingHost(from: mainHost) else { return .notDerivable(mainHost: mainHost) }
        guard declaredTrackingDomains.contains(host) else { return .notDeclared(host) }
        return .available(host)
    }

    func reportIfMainHostIsDeclaredAsTracking() {
        guard let configuration = persistenceStorage.configuration else { return }
        let mainHost = Self.mainHost(of: configuration)
        let declaredEntry = declaredTrackingDomains.first { mainHost == $0 || mainHost.hasSuffix("." + $0) }
        guard let declaredEntry, !$hasReportedMainHostDeclared.exchange(true) else { return }
        let message = "[TrackingHost] NSPrivacyTrackingDomains of the app lists \(declaredEntry), so iOS blocks every request to "
            + "\(mainHost) until the user allows tracking. List only the tracking host."
        Logger.common(message: message, level: .error, category: .network)
        misconfigurationHandler(message)
    }

    static func deriveTrackingHost(from host: String) -> String? {
        var labels = host.split(separator: ".").map(String.init)
        guard let first = labels.first, first == "api" || first.hasPrefix("api-") else { return nil }
        labels[0] = "api-tracking" + first.dropFirst(3)
        return labels.joined(separator: ".")
    }

    private static func mainHost(of configuration: MBConfiguration) -> String {
        HostNormalizer.extractHost(configuration.domain).lowercased()
    }

    static func declaredTrackingDomains(in bundle: Bundle) -> Set<String> {
        guard let url = bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
              let data = try? Data(contentsOf: url)
        else { return [] }
        return declaredTrackingDomains(manifest: data)
    }

    static func declaredTrackingDomains(manifest: Data) -> Set<String> {
        guard let plist = try? PropertyListSerialization.propertyList(from: manifest, format: nil) as? [String: Any],
              plist["NSPrivacyTracking"] as? Bool == true,
              let domains = plist["NSPrivacyTrackingDomains"] as? [String]
        else { return [] }
        return Set(domains.map { $0.lowercased() })
    }
}
