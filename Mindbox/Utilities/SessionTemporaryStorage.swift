//
//  SessionTemporaryStorage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 10.03.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

final class SessionTemporaryStorage {
    var observedCustomOperations: [String] = []
    var geoRequestCompleted = false
    var checkSegmentsRequestCompleted = false
    var isPresentingInAppMessage = false
    
    func erase() {
        observedCustomOperations = []
        geoRequestCompleted = false
        checkSegmentsRequestCompleted = false
        isPresentingInAppMessage = false
    }
}
