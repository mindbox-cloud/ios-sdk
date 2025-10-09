//
//  DatabaseLoaderProtocol.swift
//  Mindbox
//
//  Created by Sergei Semko on 9/19/25.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import CoreData

protocol DatabaseLoaderProtocol {
    
    /// Loads the persistent container and takes care of metadata preservation during repair flows.
    ///
    /// Flow:
    /// 1. Try to load the on-disk store normally.
    /// 2. If it fails, **salvage** the metadata from the on-disk file in read-only mode.
    /// 3. If disk space is critically low, create an **in-memory** store and **re-apply** preserved metadata.
    /// 4. Otherwise, attempt a repair by destroying the old store and re-creating it, then **re-apply** metadata.
    /// 5. If repair also fails, fall back to an in-memory store (no metadata re-apply here unless you add it).
    ///
    /// - Returns: A ready-to-use `NSPersistentContainer`.
    /// - Throws: The error from store loading if the initial attempt fails and repair is not possible.
    func loadPersistentContainer() throws -> NSPersistentContainer
    
    /// Creates and loads an **in-memory** Core Data container using the current model.
    ///
    /// Applies standard store options and loads the in-memory store synchronously.
    /// Typically used as a fallback when on-disk loading or repair is not possible.
    ///
    /// - Returns: A ready-to-use in-memory `NSPersistentContainer`.
    /// - Throws: Propagates errors from loading the in-memory store.
    func makeInMemoryContainer() throws -> NSPersistentContainer
    
    /// Permanently deletes the on-disk Core Data store referenced by this loader.
    ///
    /// Use this during a repair flow when you need to recreate the store from scratch.
    /// The method resolves the store URL either from the currently loaded store or
    /// from the container’s `persistentStoreDescriptions`.
    ///
    /// - Important: If you need to keep selected metadata (e.g. `ApplicationInstalledVersion`,
    ///   `ApplicationInfoUpdatedVersion`, `ApplicationInstanceId`), call
    ///   `salvageMetadataFromOnDiskStore()` **before** invoking this method and later
    ///   re-apply it with `applyMetadata(_:to:)`.
    ///
    /// - Effects: Calls `NSPersistentStoreCoordinator.destroyPersistentStore(...)`,
    ///   which removes the SQLite file and its auxiliary files (`-shm`, `-wal`).
    ///
    /// - Throws: `MBDatabaseError.persistentStoreURLNotFound` if the URL cannot be determined,
    ///   or any error propagated by Core Data while destroying the store.
    ///
    /// - Note: On iOS 15+ the API variant `type: .sqlite` is used; earlier systems fall back
    ///   to `ofType: NSSQLiteStoreType`.
    func destroy() throws
}
