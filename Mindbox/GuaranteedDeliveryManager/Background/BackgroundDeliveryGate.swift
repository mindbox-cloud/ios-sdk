//
//  BackgroundDeliveryGate.swift
//  Mindbox
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

final class BackgroundDeliveryGate: @unchecked Sendable {

    private let lock = NSLock()
    private var onFinish: ((Bool) -> Void)?
    private var eventsSuccess: Bool?
    private var confirmationsDone = false

    init(onFinish: @escaping (_ success: Bool) -> Void) {
        self.onFinish = onFinish
    }

    func eventsFinished(success: Bool) {
        finish {
            guard eventsSuccess == nil else { return nil }
            eventsSuccess = success
            return confirmationsDone ? success : nil
        }
    }

    func confirmationsFinished() {
        finish {
            confirmationsDone = true
            return eventsSuccess
        }
    }

    func finishNow(success: Bool) {
        finish { success }
    }

    private func finish(_ update: () -> Bool?) {
        let ready: (onFinish: (Bool) -> Void, success: Bool)? = lock.withLock {
            guard let onFinish, let success = update() else { return nil }
            self.onFinish = nil
            return (onFinish, success)
        }
        guard let ready else { return }
        ready.onFinish(ready.success)
    }
}
