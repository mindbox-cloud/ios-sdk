//
//  DatabaseLoaderStoreResetTests.swift
//  MindboxTests
//
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import CoreData
@testable import Mindbox

@Suite("DatabaseLoader resets the store only when it is corrupt or incompatible")
struct DatabaseLoaderStoreResetTests {

    enum ResetShape: String, CaseIterable {
        case truncatedFile
        case notADatabase
        case overwrittenHeader
        case extendedCorruptCode
        case corruptionDuringMigration
        case incompatibleVersionHash
        case missingSourceModel
        case missingMappingModel

        var error: NSError {
            switch self {
            case .truncatedFile: return sqliteError(11)
            case .notADatabase: return sqliteError(26)
            case .overwrittenHeader: return cocoaError(NSFileReadCorruptFileError, sqlite: 26)
            case .extendedCorruptCode: return cocoaError(NSFileReadUnknownError, sqlite: 779)
            case .corruptionDuringMigration:
                return cocoaError(NSMigrationError, underlying: cocoaError(NSMigrationError, sqlite: 11))
            case .incompatibleVersionHash: return cocoaError(NSPersistentStoreIncompatibleVersionHashError)
            case .missingSourceModel: return cocoaError(NSMigrationMissingSourceModelError)
            case .missingMappingModel:
                return cocoaError(NSMigrationMissingMappingModelError, underlying: cocoaError(NSInferredMappingModelError))
            }
        }
    }

    enum KeepShape: String, CaseIterable {
        case fullDiskWithoutStore
        case fullDiskWithSharedMemoryFile
        case fullDiskWithoutSidecars
        case fullDiskDuringMigration
        case accessDenied
        case noPermission
        case unknownRead
        case posixDeadlock
        case posixTextFileBusy

        var error: NSError {
            switch self {
            case .fullDiskWithoutStore:
                return NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: ["reason": "disk I/O error, code = 28"])
            case .fullDiskWithSharedMemoryFile: return cocoaError(NSFileReadUnknownError, sqlite: 4618)
            case .fullDiskWithoutSidecars: return cocoaError(NSFileReadUnknownError, sqlite: 14)
            case .fullDiskDuringMigration:
                return cocoaError(NSMigrationError, underlying: cocoaError(NSMigrationError, sqlite: 13))
            case .accessDenied: return cocoaError(NSFileReadUnknownError, sqlite: 23)
            case .noPermission:
                return NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: ["reason": "No access to file; code = 13"])
            case .unknownRead: return cocoaError(NSFileReadUnknownError)
            case .posixDeadlock:
                return cocoaError(NSFileReadUnknownError, underlying: NSError(domain: NSPOSIXErrorDomain, code: 11))
            case .posixTextFileBusy:
                return cocoaError(NSFileReadUnknownError, underlying: NSError(domain: NSPOSIXErrorDomain, code: 26))
            }
        }
    }

    @Test("A corrupt store or an incompatible model resets the store", arguments: ResetShape.allCases)
    func resetShape(_ shape: ResetShape) {
        #expect(DatabaseLoader.requiresStoreReset(after: shape.error))
    }

    @Test("Any other load error keeps the store", arguments: KeepShape.allCases)
    func keepShape(_ shape: KeepShape) {
        #expect(!DatabaseLoader.requiresStoreReset(after: shape.error))
    }
}

private func sqliteError(_ code: Int) -> NSError {
    NSError(domain: NSSQLiteErrorDomain, code: code, userInfo: [NSSQLiteErrorDomain: code])
}

private func cocoaError(_ code: Int, sqlite: Int? = nil, underlying: NSError? = nil) -> NSError {
    var userInfo: [String: Any] = [:]
    userInfo[NSSQLiteErrorDomain] = sqlite
    userInfo[NSUnderlyingErrorKey] = underlying
    return NSError(domain: NSCocoaErrorDomain, code: code, userInfo: userInfo)
}
