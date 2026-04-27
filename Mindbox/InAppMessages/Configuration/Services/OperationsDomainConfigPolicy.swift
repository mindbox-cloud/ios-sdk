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
        /// No-op: equal to stored, both empty, or incoming value is format-broken
        /// (one bad push must not destroy a working config).
        case keep
    }

    static func action(for raw: String?, currentlyStored: String?) -> Action {
        guard let value = raw, !value.isEmpty else {
            return currentlyStored == nil ? .keep : .clear
        }

        guard HostNormalizer.isValidHost(value) else {
            return .keep
        }

        return value == currentlyStored ? .keep : .save(value)
    }
}
