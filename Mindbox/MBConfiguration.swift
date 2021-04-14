//
//  MBConfiguration.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
/// This struct contains init options and  behavior configuration options
///
/// - Throws:`Mindbox.Errors.invalidConfiguration` for invalid initialization parameters

public struct MBConfiguration: Codable {
    
    public let endpoint: String
    public let domain: String
    public var previousInstallationId: String?
    public var deviceUUID: String?
    public var subscribeCustomerIfCreated: Bool

    /// Init with params
    ///
    /// - Parameter endpoint: Used for app identification
    /// - Parameter domain: Used for generating baseurl for REST
    /// - Parameter previousInstallationId: Used to create tracking continuity by uuid
    /// - Parameter deviceUUID: Used instead of the generated value
    ///
    /// - Throws:`Mindbox.Errors.invalidConfiguration` for invalid initialization parameters
    public init(
        endpoint: String,
        domain: String,
        previousInstallationId: String? = nil,
        deviceUUID: String? = nil,
        subscribeCustomerIfCreated: Bool = false
    ) throws {

        self.endpoint = endpoint
        self.domain = domain
        
        guard let url = URL(string: "https://" + domain), URLValidator(url: url).evaluate() else {
            throw Mindbox.Errors.invalidConfiguration(reason: "Invalid domain. Domain is unreachable")
        }

        guard !endpoint.isEmpty else {
            throw Mindbox.Errors.invalidConfiguration(reason: "Value endpoint can not be empty")
        }

        if let previousInstallationId = previousInstallationId, !previousInstallationId.isEmpty {
            guard UUID(uuidString: previousInstallationId) != nil else {
                throw Mindbox.Errors.invalidConfiguration(reason: "installationId doesn't match the UUID format", suggestion: nil)
            }

            guard UDIDValidator(udid: previousInstallationId).evaluate() else {
                throw Mindbox.Errors.invalidConfiguration(reason: "installationId doesn't match the UUID format", suggestion: nil)
            }

            self.previousInstallationId = previousInstallationId
        }
        if let deviceUUID = deviceUUID, !deviceUUID.isEmpty {
            guard UUID(uuidString: deviceUUID) != nil else {
                throw Mindbox.Errors.invalidConfiguration(reason: "deviceUUID doesn't match the UUID format", suggestion: nil)
            }

            guard UDIDValidator(udid: deviceUUID).evaluate() else {
                throw Mindbox.Errors.invalidConfiguration(reason: "deviceUUID doesn't match the UUID format", suggestion: nil)
            }

            self.deviceUUID = deviceUUID
        }
        self.subscribeCustomerIfCreated = subscribeCustomerIfCreated
    }

    /// Init with plist file
    ///
    /// ```
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    /// <plist version="1.0">
    /// <dict>
    ///    <key>endpoint</key>
    ///    <string>app-with-hub-IOS</string>
    ///    <key>domain</key>
    ///    <string>api.mindbox.ru</string>
    ///    <key>installationId</key>
    ///    <string></string>
    ///    <key>deviceUUID</key>
    ///    <string></string>
    /// </dict>
    /// </plist>
    /// ```
    /// - Parameter plistName: name of plist file without extension
    /// - Throws:`Mindbox.Errors.invalidConfiguration` for invalid initialization parameters or  incorrect format file
    public init(plistName: String) throws {
        let decoder = PropertyListDecoder()
        var findeURL: URL?

        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: plistName, withExtension: "plist") {
                findeURL = url
                break
            }
        }

        guard let url = findeURL else {
            throw Mindbox.Errors.invalidConfiguration(reason: "file with name \(plistName) not found")
        }

        guard let data = try? Data(contentsOf: url) else {
            throw Mindbox.Errors.invalidConfiguration(reason: "file with name \(plistName) cannot be read")
        }

        guard let configuration = try? decoder.decode(MBConfiguration.self, from: data) else {
            throw Mindbox.Errors.invalidConfiguration(reason: "file with name \(plistName) contains invalid properties")
        }
        self = configuration
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case domain
        case previousInstallationId
        case deviceUUID
        case subscribeCustomerIfCreated
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let endpoint = try values.decode(String.self, forKey: .endpoint)
        let domain = try values.decode(String.self, forKey: .domain)
        var previousInstallationId: String? = nil
        if let value = try? values.decode(String.self, forKey: .previousInstallationId) {
            if !value.isEmpty {
                previousInstallationId = value
            }
        }
        var deviceUUID: String? = nil
        if let value = try? values.decode(String.self, forKey: .deviceUUID) {
            if !value.isEmpty {
                deviceUUID = value
            }
        }
        let subscribeCustomerIfCreated = try values.decodeIfPresent(Bool.self, forKey: .subscribeCustomerIfCreated) ?? false
        try self.init(
            endpoint: endpoint,
            domain: domain,
            previousInstallationId: previousInstallationId,
            deviceUUID: deviceUUID,
            subscribeCustomerIfCreated: subscribeCustomerIfCreated
        )
    }

}
