//
//  CDEvent+CoreDataProperties.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 05.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//
//

import Foundation
import CoreData


extension CDEvent {
    
    @nonobjc public class func fetchRequest(retryDeadLine: TimeInterval = 60) -> NSFetchRequest<CDEvent> {
        let request = NSFetchRequest<CDEvent>(entityName: "CDEvent")
        var subpredicates: [NSPredicate] = []
        if let monthLimitDateStamp = lifeLimitDate?.timeIntervalSince1970 {
            subpredicates.append(
                NSPredicate(format: "%K > %@", argumentArray: [#keyPath(CDEvent.timestamp), monthLimitDateStamp])
            )
        }
        if let deadlineDate = Calendar.current.date(byAdding: .second, value: -Int(retryDeadLine), to: Date()) {
            subpredicates.append(
                NSPredicate(format: "%K < %@", argumentArray: [#keyPath(CDEvent.retryTimestamp), deadlineDate.timeIntervalSince1970])
            )
        }
        request.predicate = NSCompoundPredicate(type: .or, subpredicates: subpredicates)
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CDEvent.retryTimestamp), ascending: true),
            NSSortDescriptor(key: #keyPath(CDEvent.timestamp), ascending: true),
        ]
        return request
    }
    
    public class func fetchRequest(by transactionId: String) -> NSFetchRequest<CDEvent> {
        let request = NSFetchRequest<CDEvent>(entityName: "CDEvent")
        request.predicate = NSPredicate(format: "%K == %@", argumentArray: [#keyPath(CDEvent.transactionId), transactionId])
        return request
    }
    
    public class func deprecatedEventsFetchRequest() -> NSFetchRequest<CDEvent> {
        let request = NSFetchRequest<CDEvent>(entityName: "CDEvent")
        if let monthLimitDateStamp = lifeLimitDate?.timeIntervalSince1970 {
            request.predicate = NSPredicate(format: "%K <= %@", argumentArray: [#keyPath(CDEvent.timestamp), monthLimitDateStamp])
        }
        return request
    }
    
    static var lifeLimitDate: Date? {
        let calendar: Calendar = .current
        guard let monthLimitDate = calendar.date(byAdding: .month, value: -6, to: Date()) else {
            return nil
        }
        return monthLimitDate
    }
    
    @NSManaged public var body: String?
    @NSManaged public var timestamp: Double
    @NSManaged public var transactionId: String?
    @NSManaged public var type: String?
    @NSManaged public var retryTimestamp: Double
    
}
