//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

let resolver = DIManager.shared.container

public class MindBox {
    /// Singleton value for interaction with sdk
    /// Side effect is setup DI
    public static var shared: MindBox = {
        DIManager.shared.registerServices()
		return MindBox()
    }()

    // MARK: - Elements

    @Injected var configurationStorage: IConfigurationStorage
    @Injected var persistenceStorage: IPersistenceStorage

    let coreController: CoreController

    // MARK: - Property

    public weak var delegate: MindBoxDelegate?

    // MARK: - Init

    private init() {
        coreController = CoreController()
    }

    // MARK: - MindBox

    public func initialization(configuration: MBConfiguration) {
        coreController.initialization(configuration: configuration)
    }

    public func deviceUUID() throws -> String {
        if let value = persistenceStorage.deviceUUID {
            return value
        } else {
            throw NSError()
        }
    }

    public var APNSToken: String? {
        get {
            persistenceStorage.apnsToken
        }
    }

    public var sdkVersion: String {
        get {
            return Utilities.fetch.sdkVersion ?? "unknown"
        }
    }

    public func apnsTokenUpdate(token: String) {
        coreController.apnsTokenDidUpdate(token: token)
        persistenceStorage.apnsToken = token
    }

    // MARK: - Private
}
