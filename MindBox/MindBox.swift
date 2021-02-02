//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

let diManager = DIManager.shared

public class MindBox {

    /// Singleton value for interaction with sdk
    /// It has setup DI container  as side effect  on init
    /// - Warning: All calls which use DI containers objects, mast go through `MindBox.shared`
    public static var shared = MindBox()
    
    // MARK: - Elements

    @Injected var configurationStorage: ConfigurationStorage
    @Injected var persistenceStorage: PersistenceStorage
    @Injected var utilitiesFetcher: UtilitiesFetcher
    
    /// Internal process controller
    let coreController = CoreController()

    // MARK: - Property

	/// Delegate for sending events t
    weak var delegate: MindBoxDelegate?

    // MARK: - Init

    private init() {
        DIManager.shared.registerServices()
    }

    // MARK: - MindBox

    /// This function starting initialization case using `configuration`.
    /// - Parameter configuration: MBConfiguration struct with configuration
    public func initialization(configuration: MBConfiguration) {
        coreController.initialization(configuration: configuration)
    }

	/// Method to get deviceUUID used for first initialization
    /// - Throws: MindBox.Errors.invalidAccess until first initialization did success
    public func deviceUUID() throws -> String {
        if let value = persistenceStorage.deviceUUID {
            return value
        } else {
            throw MindBox.Errors.invalidAccess(reason: "deviceUUID unavailable until first initialization did success", suggestion: "Try later")
        }
    }

    /// - Returns: APNSToken sent to the analytics system
    public var APNSToken: String? {
        return persistenceStorage.apnsToken
    }

    /// - Returns: version from bundle
    public var sdkVersion: String {
        get {
            return utilitiesFetcher.sdkVersion ?? "unknown"
        }
    }

	/// Method for keeping apnsTokenUpdate actuality
    public func apnsTokenUpdate(token: String) {
        coreController.apnsTokenDidUpdate(token: token)
        persistenceStorage.apnsToken = token
    }

    // MARK: - Private
}
