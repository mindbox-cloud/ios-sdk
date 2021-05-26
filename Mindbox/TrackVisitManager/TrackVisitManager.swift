//
//  TrackVistiManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.04.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import UIKit

final class TrackVisitManager {
    private let databaseRepository: MBDatabaseRepository

    init(
        databaseRepository: MBDatabaseRepository
    ) {
        self.databaseRepository = databaseRepository
    }

    func track(_ type: TrackVisitType) throws {
        switch type {
        case let .launch(options):
            try handleLaunch(options)
        case let .universalLink(userActivity):
            try handleUniversalLink(userActivity)
        case let .push(response):
            try handlePush(response)
        case let .launchScene(options):
            if #available(iOS 13.0, *) {
                try handleLaunchScene(options)
            }
        }
    }
    
    func trackForeground() throws {
        let encodable = TrackVisit()
        Log("Tracked Visit event type direct").category(.visit).level(.info).make()
        try sendTrackVisit(encodable)
    }

    func trackDirect() throws {
        let encodable = TrackVisit(source: .direct)
        Log("Tracked Visit event type direct").category(.visit).level(.info).make()
        try sendTrackVisit(encodable)
    }

    private func handleLaunch(_ options: [UIApplication.LaunchOptionsKey: Any]?) throws {
        if let options = options, let dict = options[.userActivityDictionary] as? NSDictionary {
            if let userActivity = dict.first(where: { $0.value as? NSUserActivity != nil })?.value as? NSUserActivity {
                try handleUniversalLink(userActivity)
            }
        }
    }

    @available(iOS 13.0, *)
    private func handleLaunchScene(_ options: UIScene.ConnectionOptions) throws {
        if let userActivity = options.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            try handleUniversalLink(userActivity)
        }
    }

    private func handleUniversalLink(_ userActivity: NSUserActivity) throws {
        let encodable = TrackVisit(url: userActivity.webpageURL, source: .link)
        try sendTrackVisit(encodable)
        Log("Tracked Visit event type: universal link").category(.visit).level(.info).make()
    }

    private func handlePush(_ response: UNNotificationResponse) throws {

        let encodable = TrackVisit(source: .push)
        try sendTrackVisit(encodable)
        Log("Tracked Visit event type: push").category(.visit).level(.info).make()
    }
    
    private func sendTrackVisit<E: Encodable>(_ encodable: E) throws {
        let event = Event(type: .trackVisit, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
}

public enum TrackVisitType {
    case universalLink(NSUserActivity)
    case push(UNNotificationResponse)
    case launch([UIApplication.LaunchOptionsKey: Any]?)
    @available(iOS 13.0, *)
    case launchScene(UIScene.ConnectionOptions)
}
