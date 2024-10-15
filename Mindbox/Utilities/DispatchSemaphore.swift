//
//  DispatchSemaphore.swift
//  Mindbox
//
//  Created by Pavel Zavarin on 13.05.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

extension DispatchSemaphore {

    func lock<T>(execute task: () throws -> T) rethrows -> T {
        wait()
        defer { signal() }
        return try task()
    }
}
