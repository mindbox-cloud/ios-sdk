//
//  MBPersistentContainer.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 29.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

class MBPersistentContainer: NSPersistentContainer {
    
    static var applicationGroupIdentifier: String? = nil
        
    override class func defaultDirectoryURL() -> URL {
        guard let applicationGroupIdentifier = applicationGroupIdentifier else {
            return super.defaultDirectoryURL()
        }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) ?? super.defaultDirectoryURL()
    }
    
}
