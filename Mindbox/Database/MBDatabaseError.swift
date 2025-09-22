//
//  MBDatabaseError.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

public enum MBDatabaseError: LocalizedError {

    case unableCreateDatabaseModel
    case unableCreateManagedObjectModel(with: URL)
    case unableToLoadPeristentStore(localizedDescription: String)
    case persistentStoreURLNotFound
    case persistentStoreNotExistsAtURL(path: String)

    public var errorDescription: String {
        switch self {
        case .unableCreateDatabaseModel:
            return "[DatabaseLoader] Unable to create \(Constants.Database.mombName).xcdatamodel"
        case .unableCreateManagedObjectModel(let url):
            return "[DatabaseLoader] Unable to create NSManagedObjectModel from url: \(url)"
        case .unableToLoadPeristentStore(let localizedDescription):
            return "[DatabaseLoader] Unable to load persistent store with error: \(localizedDescription)"
        case .persistentStoreURLNotFound:
            return "[DatabaseLoader] Unable to find persistentStoreURL"
        case .persistentStoreNotExistsAtURL(let path):
            return "[DatabaseLoader] Unable to find persistentStoreURL at path: \(path)"
        }
    }
}
