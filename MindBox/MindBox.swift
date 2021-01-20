//
//  MindBox.swift
//  MindBox
//
//  Created by Mikhail Barilov on 12.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit
import AdSupport

let resolver = DIManager.shared.container

public class MindBox {
    public static var shared: MindBox = {
        DIManager.shared.registerServices()
		return MindBox()
    }()

    // MARK: - Elemets

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

        let deviceIdentifierForVendor = UIDevice.current.identifierForVendor

        ASIdentifierManager.shared().advertisingIdentifier

        UUID()

        configurationStorage.save(configuration: configuration)
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
