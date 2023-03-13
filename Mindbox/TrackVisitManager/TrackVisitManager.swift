//
//  TrackVistiManager.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.04.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

final class TrackVisitManager {
    private let databaseRepository: MBDatabaseRepository

    init(
        databaseRepository: MBDatabaseRepository
    ) {
        self.databaseRepository = databaseRepository
    }

    func track(_ type: TrackVisitType) throws {
        switch type {
        case let .launch(options), let .launchScene(options):
            try handleLaunch(options)
        case let .universalLink(userActivity):
            try handleUniversalLink(userActivity)
        case let .push(response):
            try handlePush(response)
        }
    }

    @objc func track(data: TrackVisitData) throws {
        if let userActivity = data.universalLink {
            try handleUniversalLink(userActivity)
        } else if let response = data.push {
            try handlePush(response)
        } else if #available(iOS 13.0, *), let sceneOptions = data.sceneOptions as? UIScene.ConnectionOptions {
            try handleLaunch(sceneOptions)
        } else if let launchOptions = data.launchOptions {
            try handleLaunch(launchOptions)
        }
    }

    func trackForeground() throws {
        let encodable = TrackVisit()
        Logger.common(message: "Tracked Visit event type direct", level: .info, category: .visit)
        try sendTrackVisit(encodable)
    }

    func trackDirect() throws {
        let encodable = TrackVisit(source: .direct)
        Logger.common(message: "Tracked Visit event type direct", level: .info, category: .visit)
        try sendTrackVisit(encodable)
    }

    private func handleLaunch(_ options: LaunchOptions?) throws {
        guard let options = options else { return }

        if #available(iOS 13.0, *),
           case let sceneOptions as UIScene.ConnectionOptions = options,
           let userActivity = sceneOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            try handleUniversalLink(userActivity)
        }
    }

    private func handleUniversalLink(_ userActivity: NSUserActivity) throws {
        let encodable = TrackVisit(url: userActivity.webpageURL, source: .link)
        try sendTrackVisit(encodable)
        Logger.common(message: "Tracked Visit event type: universal link", level: .info, category: .visit)
    }

    private func handlePush(_ response: UNNotificationResponse) throws {
        let encodable = TrackVisit(source: .push)
        try sendTrackVisit(encodable)
        Logger.common(message: "Tracked Visit event type: push", level: .info, category: .visit)
    }

    private func sendTrackVisit<E: Encodable>(_ encodable: E) throws {
        let event = Event(type: .trackVisit, body: BodyEncoder(encodable: encodable).body)
        try databaseRepository.create(event: event)
    }
}

public enum TrackVisitType {
    case universalLink(NSUserActivity)
    case push(UNNotificationResponse)
    case launch(LaunchOptions?)
    case launchScene(LaunchOptions?)
}

@objcMembers
public class TrackVisitData: NSObject {
    public var universalLink: NSUserActivity?
    public var push: UNNotificationResponse?
    public var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    public var sceneOptions: Any?
}

public protocol LaunchOptions {}

extension Dictionary: LaunchOptions where Key == UIApplication.LaunchOptionsKey, Value == Any {}

@available(iOS 13.0, *)
extension UIScene.ConnectionOptions: LaunchOptions {}
