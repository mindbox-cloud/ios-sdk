//
//  OperationsDomainConfigPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

/// Decides save / clear / keep for the operations host coming from JSON config.
/// Extracted from `InAppConfigurationManager` so it can be unit-tested in isolation.
enum OperationsDomainConfigPolicy {

    enum Action: Equatable {
        case save(String)
        /// Config explicitly cleared the value (null / missing / empty).
        case clear
        /// No-op: nothing stored and nothing came, or canonicalized incoming
        /// value already equals the stored one.
        case keep
        /// Incoming value is format-broken — previous value kept intact
        /// (one bad push must not destroy a working config). Carries the raw
        /// input so the caller can log it.
        case rejected(String)
    }

    static func action(for raw: String?, currentlyStored: String?) -> Action {
        guard let value = raw, !value.isEmpty else {
            return currentlyStored == nil ? .keep : .clear
        }

        guard URLValidator.isValidHost(HostNormalizer.extractHost(value)) else {
            return .rejected(value)
        }

        // Store canonical `scheme://host` so backend's choice of `http`/`https`
        // is preserved across restarts and trailing slashes don't cause re-saves.
        let normalized = HostNormalizer.toBaseURLString(value)
        return normalized == currentlyStored ? .keep : .save(normalized)
    }
}
