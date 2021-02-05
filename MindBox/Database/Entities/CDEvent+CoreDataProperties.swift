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
        let request = NSFetchRequest<CDEvent>(entityName: "CDEvent")
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CDEvent.timestamp), ascending: true)]
        return request
    }
    
    public class func fetchRequest(by transactionId: String) -> NSFetchRequest<CDEvent> {
        let request = NSFetchRequest<CDEvent>(entityName: "CDEvent")
        request.predicate = NSPredicate(format: "%K == %@", [#keyPath(CDEvent.transactionId), transactionId])
        return request
    }

    @NSManaged public var body: String?
    @NSManaged public var timestamp: Double
    @NSManaged public var transactionId: String?
    @NSManaged public var type: String?

}
