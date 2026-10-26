//
//  OperationsDomainConfigPolicy.swift
//  Mindbox
//
//  Created by Sergei Semko on 4/27/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum OperationsDomainConfigPolicy {

    enum Action: Equatable {
        case save(String)
        case clear
        case keep
        case rejected(String)
    }

    static func action(for raw: String?, currentlyStored: String?) -> Action {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = trimmed, !value.isEmpty else {
            return currentlyStored == nil ? .keep : .clear
        }

        guard URLValidator.isValidHostWithOptionalPath(HostNormalizer.extractHost(value)) else {
            return .rejected(value)
        }

        let normalized = HostNormalizer.toBaseURLString(value)
        return normalized == currentlyStored ? .keep : .save(normalized)
    }
}
