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
                break
            }
        }

        guard let url = findeURL else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard let configuration = try? decoder.decode(MBConfiguration.self, from: data) else {
            return nil
        }

        self = configuration
        Logger.common(message: "MBConfiguration: Successfully initialized configuration. Configuration: \(configuration)", level: .info, category: .notification)
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
        let endpoint = try values.decode(String.self, forKey: .endpoint)
        let domain = try values.decode(String.self, forKey: .domain)
        var previousInstallationId: String?
        
        if let value = try? values.decode(String.self, forKey: .previousInstallationId) {
            if !value.isEmpty {
                previousInstallationId = value
            }
        }
        
        var previousDeviceUUID: String?
        
        if let value = try? values.decode(String.self, forKey: .previousDeviceUUID) {
            if !value.isEmpty {
                previousDeviceUUID = value
            }
        }
        
        let subscribeCustomerIfCreated = try values.decodeIfPresent(Bool.self, forKey: .subscribeCustomerIfCreated) ?? false
        
        self.endpoint = endpoint
        self.domain = domain
        self.previousDeviceUUID = previousDeviceUUID
        self.previousInstallationId = previousInstallationId
        self.subscribeCustomerIfCreated = subscribeCustomerIfCreated
        Logger.common(message: "MBConfiguration: Successfully initialized configuration. Configuration: \(self)", level: .info, category: .notification)
    }
}

