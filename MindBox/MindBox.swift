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
    public static var shared: MindBox = {
        DIManager.shared.registerServices()
		return MindBox()
    }()

    // MARK: - Elemets
    
    private let coreController: CoreController

    // MARK: - Property

    @Injected var configurationStorage: IConfigurationStorage
    @Injected var persistenceStorage: IPersistenceStorage

    // MARK: - Init

    private init() {
        coreController = CoreController()
    }

    // MARK: - MindBox

    public func initialization(config: MBConfiguration) {
        configurationStorage.domain = config.domain
        configurationStorage.endpoint = config.endpoint
    }

    public func getUUID() throws -> String {
        if let value = persistenceStorage.deviceUUID {
            return value
        } else {
            throw NSError()

        }
    }

    // MARK: - Private
}
