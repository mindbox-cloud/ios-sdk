//
//  MBConfiguration.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//


import Foundation
import MindboxLogger

public struct MBConfiguration: Codable {
    public let endpoint: String
    public let domain: String
    public var previousInstallationId: String?
    public var previousDeviceUUID: String?
    public var subscribeCustomerIfCreated: Bool
    
    public init?(plistName: String) {
        let decoder = PropertyListDecoder()
        var findeURL: URL?

        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: plistName, withExtension: "plist") {
                findeURL = url
                Logger.common(message: "MBConfiguration: Successfully finded URL. findeURL: \(String(describing: findeURL))", level: .info, category: .notification)
                break
            }
        }

        guard let url = findeURL else {
            Logger.common(message: "MBConfiguration: Failed to find URL: findeURL: \(String(describing: findeURL))", level: .error, category: .notification)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            Logger.common(message: "MBConfiguration: Failed to get data by URL. url: \(url)", level: .error, category: .notification)
            return nil
        }

        guard let configuration = try? decoder.decode(MBConfiguration.self, from: data) else {
            Logger.common(message: "MBConfiguration: Failed to decode configuration from data. data: \(data)", level: .error, category: .notification)
            return nil
        }

        self = configuration
        Logger.common(message: "MBConfiguration: Successfully initialized configuration. configuration. \(configuration)", level: .info, category: .notification)
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case domain
        case previousInstallationId
        case previousDeviceUUID
        case subscribeCustomerIfCreated
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        Logger.common(message: "MBConfiguration: Successfully received values. values: \(values)", level: .info, category: .notification)
        let endpoint = try values.decode(String.self, forKey: .endpoint)
        Logger.common(message: "MBConfiguration: Successfully received endpoint. endpoint: \(endpoint)", level: .info, category: .notification)
        let domain = try values.decode(String.self, forKey: .domain)
        Logger.common(message: "MBConfiguration: Successfully received domain. domain: \(endpoint)", level: .info, category: .notification)
        var previousInstallationId: String?
        if let value = try? values.decode(String.self, forKey: .previousInstallationId) {
            Logger.common(message: "MBConfiguration: Successfully decoded value by values for key 'previousInstallationId'. value: \(value)", level: .info, category: .notification)
            if !value.isEmpty {
                previousInstallationId = value
            }
        }
        var previousDeviceUUID: String?
        if let value = try? values.decode(String.self, forKey: .previousDeviceUUID) {
            Logger.common(message: "MBConfiguration: Successfully decoded value by values for key 'previousDeviceUUID'. value: \(value)", level: .info, category: .notification)
            if !value.isEmpty {
                previousDeviceUUID = value
            }
        }
        let subscribeCustomerIfCreated = try values.decodeIfPresent(Bool.self, forKey: .subscribeCustomerIfCreated) ?? false
        Logger.common(message: "MBConfiguration: subscribeCustomerIfCreated: \(subscribeCustomerIfCreated)", level: .info, category: .notification)
        
        self.endpoint = endpoint
        self.domain = domain
        self.previousDeviceUUID = previousDeviceUUID
        self.previousInstallationId = previousInstallationId
        self.subscribeCustomerIfCreated = subscribeCustomerIfCreated
        Logger.common(message: "MBConfiguration: Successfully initialized configuration. configuration", level: .info, category: .notification)
    }
}

