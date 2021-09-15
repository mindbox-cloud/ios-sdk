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
            try handleLaunch(options as? [UIApplication.LaunchOptionsKey : Any])
        case let .universalLink(userActivity):
            guard let userActivity = userActivity as? NSUserActivity else { fatalError("Cant cust") }
            try handleUniversalLink(userActivity)
        case let .push(response):
            guard let response = response as? UNNotificationResponse else { fatalError("Cant cust") }
            try handlePush(response)
        case let .launchScene(options):
            if #available(iOS 13.0, *) {
                guard let options = options as? UIScene.ConnectionOptions else { fatalError("Cant cust") }
                try handleLaunchScene(options)
            }
        case .error:
            fatalError("Unknown type")
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
    
    case universalLink(NSObject)
    case push(NSObject)
    case launch(NSObject?)
    case launchScene(NSObject)
    case error
}

extension TrackVisitType {
    init(type: PlaceType, options: NSObject?) {
        if type == .universalLink {
            self = .universalLink(options!)
        } else if type == .launch {
            self = .launch(options)
        } else if type == .launchScene {
            self = .launchScene(options!)
        } else if type == .push {
            self = .push(options!)
        } else {
            self = .error
        }
    }
}
public enum PlaceType {
    
    case universalLink
    case push
    case launch
    case launchScene
}
