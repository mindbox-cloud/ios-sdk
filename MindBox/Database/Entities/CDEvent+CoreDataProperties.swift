//
//  CDEvent+CoreDataProperties.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 04.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//
//

import Foundation
import CoreData


extension CDEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDEvent> {
        return NSFetchRequest<CDEvent>(entityName: "CDEvent")
    }

    @NSManaged public var body: String?
    @NSManaged public var timestamp: Double
    @NSManaged public var transactionId: String?
    @NSManaged public var type: String?

}
