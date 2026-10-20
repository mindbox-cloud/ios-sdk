//
//  SQLiteLogicalSizeMeasurer.swift
//  MindboxLogger
//
//  Created by Sergei Semko on 9/11/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import SQLite3

protocol DatabaseSizeMeasuring {
    func sizeKB() -> Int
}

final class SQLiteLogicalSizeMeasurer: DatabaseSizeMeasuring {
    private let urlProvider: () -> URL?

    init(urlProvider: @escaping () -> URL?) {
        self.urlProvider = urlProvider
    }

    func sizeKB() -> Int {
        guard let url = urlProvider() else { return 0 }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let dbUnwrapped = db else { return 0 }
        defer { sqlite3_close(dbUnwrapped) }

        func pragmaInt(_ name: String) -> Int64 {
            var stmt: OpaquePointer?
            defer { if stmt != nil { sqlite3_finalize(stmt) } }
            guard sqlite3_prepare_v2(dbUnwrapped, "PRAGMA \(name);", -1, &stmt, nil) == SQLITE_OK,
                  sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return sqlite3_column_int64(stmt, 0)
        }

        let pageSize  = pragmaInt("page_size")
        let pageCount = pragmaInt("page_count")
        let freeList  = pragmaInt("freelist_count")
        let usedBytes = max(0, (pageCount - freeList)) * pageSize
        return Int(usedBytes / 1024)
    }
}
