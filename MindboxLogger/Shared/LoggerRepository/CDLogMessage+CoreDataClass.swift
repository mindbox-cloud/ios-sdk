//
//  CDLogMessage+CoreDataClass.swift
//  MindboxLogger
//
//  Created by Akylbek Utekeshev on 10.02.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import CoreData

public class CDLogMessage: NSManagedObject {}

extension CDLogMessage {
    @NSManaged public var timestamp: Date
    @NSManaged public var message: String
}
