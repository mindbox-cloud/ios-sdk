//
//  SessionTemporaryStorage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 10.03.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

final class SessionTemporaryStorage {
    var observedCustomOperations: Set<String> = []
    var operationsFromSettings: Set<String> = []
    var geoRequestCompleted = false
    var checkSegmentsRequestCompleted = false
    var checkProductSegmentsRequestCompleted = false
    var isPresentingInAppMessage = false
    var mockHashNumber: Int?
    
    var customOperations: Set<String> {
        return observedCustomOperations.union(operationsFromSettings)
    }
    
    func erase() {
        observedCustomOperations = []
        operationsFromSettings = []
        geoRequestCompleted = false
        checkSegmentsRequestCompleted = false
        checkProductSegmentsRequestCompleted = false
        isPresentingInAppMessage = false
    }
}
