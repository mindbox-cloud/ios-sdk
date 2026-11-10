//
//  TrackingIdsResolver.swift
//  Mindbox
//
//  Created by Sergei Semko on 02.11.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

enum TrackingIdsState: Equatable {
    case unknown
    case revoked
    case granted(UUID)
}

struct TrackingId: Equatable {
    static let appleType = "apple"

    let type: String
    let value: String

    var maskedValue: String {
        "sha256:" + sha256Hex("\(type):\(value)").prefix(8)
    }
}

enum TrackingIdsAttachment: Equatable {
    case cleared
    case identifiers([TrackingId], trackingHost: String)

    var ids: [TrackingId] {
        switch self {
        case .cleared: return []
        case let .identifiers(ids, _): return ids
        }
    }

    var trackingHost: String? {
        guard case let .identifiers(_, host) = self else { return nil }
        return host
    }

    var carriesTrackingIds: Bool {
        !ids.isEmpty
    }

    var jsonArray: [[String: String]] {
        ids.map { ["type": $0.type, "value": $0.value] }
    }

    func masking(_ body: Data?) -> Data? {
        guard let body, var text = String(data: body, encoding: .utf8) else { return nil }
        ids.forEach { text = text.replacingOccurrences(of: $0.value, with: $0.maskedValue) }
        return Data(text.utf8)
    }

    var hash: String {
        sha256Hex(ids.map { "\($0.type):\($0.value)" }.joined(separator: ","))
    }
}

struct TrackingIdsRecord: Equatable {
    enum Reference: Equatable {
        case hash(String)
        case unconfirmed
    }

    private static let unconfirmedValue = "unconfirmed"

    let instanceId: String
    let reference: Reference

    init(instanceId: String?, reference: Reference) {
        self.instanceId = instanceId ?? ""
        self.reference = reference
    }

    init?(rawValue: String) {
        guard let separator = rawValue.lastIndex(of: ":") else { return nil }
        let value = String(rawValue[rawValue.index(after: separator)...])
        instanceId = String(rawValue[..<separator])
        reference = value == Self.unconfirmedValue ? .unconfirmed : .hash(value)
    }

    var rawValue: String {
        switch reference {
        case let .hash(hash): return instanceId + ":" + hash
        case .unconfirmed: return instanceId + ":" + Self.unconfirmedValue
        }
    }

    static func reference(in storage: PersistenceStorage) -> Reference? {
        guard let record = storage.trackingIdsRecord.flatMap(Self.init(rawValue:)) else { return nil }
        return record.instanceId == (storage.applicationInstanceId ?? "") ? record.reference : .unconfirmed
    }
}

private func sha256Hex(_ text: String) -> String {
    SHA256().hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
}

final class TrackingIdsResolver {
    struct FirstSend {
        fileprivate let claim: Int
    }

    private struct Claims {
        var count = 0
        var firstSends: [String: Int] = [:]
    }

    @Locked private(set) var state: TrackingIdsState = .unknown
    @Locked private var claims = Claims()

    func update(identifier: UUID?) {
        if let identifier, UDIDValidator(udid: identifier.uuidString).evaluate() {
            state = .granted(identifier)
        } else {
            state = .revoked
        }
        let detail = state == .revoked ? " (nil or zeros)" : ""
        Logger.common(message: "[TrackingIds] Setter: \(state.logDescription)\(detail)", level: .debug, category: .general)
    }

    func expectFirstSend(of event: Event) {
        guard Self.canCarryTrackingIds(event.type) else { return }
        $claims.mutate { $0.firstSends[event.transactionId] = $0.count }
    }

    func takeFirstSend(of event: Event) -> FirstSend? {
        $claims.mutate { $0.firstSends.removeValue(forKey: event.transactionId) }.map(FirstSend.init)
    }

    func markUnconfirmed(in storage: PersistenceStorage) {
        $claims.mutate { claims in
            claims.count += 1
            storage.trackingIdsRecord = TrackingIdsRecord(instanceId: storage.applicationInstanceId, reference: .unconfirmed).rawValue
        }
    }

    func accept(_ hash: String, from firstSend: FirstSend, instanceId: String?, in storage: PersistenceStorage) -> Bool {
        $claims.mutate { claims in
            guard firstSend.claim == claims.count else { return false }
            storage.trackingIdsRecord = TrackingIdsRecord(instanceId: instanceId, reference: .hash(hash)).rawValue
            return true
        }
    }

    func attachment(for type: Event.Operation, trackingHost: @autoclosure () -> String?) -> TrackingIdsAttachment? {
        guard Self.canCarryTrackingIds(type) else { return nil }
        switch state {
        case .unknown:
            return nil
        case .revoked:
            return .cleared
        case let .granted(identifier):
            guard let trackingHost = trackingHost() else { return nil }
            return .identifiers([TrackingId(type: TrackingId.appleType, value: identifier.uuidString)], trackingHost: trackingHost)
        }
    }

    private static func canCarryTrackingIds(_ type: Event.Operation) -> Bool {
        type == .trackingIdsUpdated || type == .keepAlive
    }
}

extension TrackingIdsState {
    var logDescription: String {
        switch self {
        case .unknown: return "unknown"
        case .revoked: return "revoked"
        case .granted: return "granted"
        }
    }
}

extension TrackingIdsAttachment {
    var logDescription: String {
        carriesTrackingIds ? ids.map(\.type).joined(separator: ", ") : "none"
    }

    var logHash: String { "sha256: " + hash.prefix(8) }

    func sentLogMessage(operation: String) -> String {
        let details = carriesTrackingIds ? "\(operation), \(logHash)" : operation
        return "Sent tracking ids: \(logDescription) (\(details))"
    }
}
