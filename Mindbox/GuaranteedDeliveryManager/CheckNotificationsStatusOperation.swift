//
//  CheckNotificationsStatusOperation.swift
//  Mindbox
//
//  Created by Sergei Semko on 7/31/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation

typealias CheckNotifWork = (@escaping () -> Void) -> Void

final class CheckNotificationsOperation: AsyncOperation, @unchecked Sendable {

    private let work: CheckNotifWork

    init(work: @escaping CheckNotifWork) { self.work = work }

    override func main() {
        guard !isCancelled else { finish(); return }
        work { [weak self] in self?.finish() }
    }
}
