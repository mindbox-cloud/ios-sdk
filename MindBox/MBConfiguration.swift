//
//  MBConfiguration.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
/// This struct contains init options and  behavior configuration options
///
/// - Throws:`MindBox.Errors.invalidConfiguration` for invalid initialization parameters

public struct MBConfiguration: Codable {
    
    public let endpoint: String
    public let domain: String
    public var installationId: String?
    public var deviceUUID: String?
    ///public var canRequestTrackingAuthorization: Bool?

    /// Init with params
    ///
    /// - Parameter endpoint: Used for app identification
    /// - Parameter domain: Used for generating baseurl for REST
    /// - Parameter installationId: Used to create tracking continuity by uuid
    /// - Parameter deviceUUID: Used instead of the generated value
    ///
    /// - Throws:`MindBox.Errors.invalidConfiguration` for invalid initialization parameters
    public init(
        endpoint: String,
        domain: String,
        installationId: String? = nil,
        deviceUUID: String? = nil
    ) throws {

        self.endpoint = endpoint
        self.domain = domain
        
        guard let url = URL(string: "https://" + domain), URLValidator(url: url).evaluate() else {
            throw MindBox.Errors.invalidConfiguration(reason: "Invalid domain. Domain is unreachable")
        }

        guard !endpoint.isEmpty else {
            throw MindBox.Errors.invalidConfiguration(reason: "Value endpoint can not be empty")
        }

        if let installationId = installationId, !installationId.isEmpty {
            guard UUID(uuidString: installationId) != nil else {
                throw MindBox.Errors.invalidConfiguration(reason: "installationId doesn't match the UUID format", suggestion: nil)
            }

            guard UDIDValidator(udid: installationId).evaluate() else {
                throw MindBox.Errors.invalidConfiguration(reason: "installationId doesn't match the UUID format", suggestion: nil)
            }

            self.installationId = installationId
        }
        if let deviceUUID = deviceUUID, !deviceUUID.isEmpty {
            guard UUID(uuidString: deviceUUID) != nil else {
                throw MindBox.Errors.invalidConfiguration(reason: "deviceUUID doesn't match the UUID format", suggestion: nil)
            }

            guard UDIDValidator(udid: deviceUUID).evaluate() else {
                throw MindBox.Errors.invalidConfiguration(reason: "deviceUUID doesn't match the UUID format", suggestion: nil)
            }

            self.deviceUUID = deviceUUID
        }
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
    /// - Throws:`MindBox.Errors.invalidConfiguration` for invalid initialization parameters or  incorrect format file
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
            throw MindBox.Errors.invalidConfiguration(reason: "file with name \(plistName) not found")
        }

        guard let data = try? Data(contentsOf: url) else {
            throw MindBox.Errors.invalidConfiguration(reason: "file with name \(plistName) cannot be read")
        }

        guard let configuration = try? decoder.decode(MBConfiguration.self, from: data) else {
            throw MindBox.Errors.invalidConfiguration(reason: "file with name \(plistName) contains invalid properties")
        }
        self = configuration
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case domain
        case installationId
        case deviceUUID
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let endpoint = try values.decode(String.self, forKey: .endpoint)
        let domain = try values.decode(String.self, forKey: .domain)
        var installationId: String? = nil
        if let value = try? values.decode(String.self, forKey: .installationId) {
            if !value.isEmpty {
                installationId = value
            }
        }
        
        var deviceUUID: String? = nil
        do {
            let value = try values.decode(String.self, forKey: .deviceUUID)
            if !value.isEmpty {
                deviceUUID = value
            }
        }
        try self.init(
            endpoint: endpoint,
            domain: domain,
            installationId: installationId,
            deviceUUID: deviceUUID
        )
    }

}
