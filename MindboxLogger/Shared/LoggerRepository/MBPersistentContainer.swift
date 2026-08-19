//
//  MBPersistentContainer.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import CoreData

public class MBPersistentContainer: NSPersistentContainer, @unchecked Sendable {

    // Written by two independent database loaders (the SDK's and the logger's), each on its own
    // queue, and read by every container init — TSan-confirmed race without the lock.
    @Locked public static var applicationGroupIdentifier: String?

    override public class func defaultDirectoryURL() -> URL {
        guard let applicationGroupIdentifier = applicationGroupIdentifier else {
            return super.defaultDirectoryURL()
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) ?? super.defaultDirectoryURL()
    }
}
