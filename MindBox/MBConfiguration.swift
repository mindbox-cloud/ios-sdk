//
//  MBConfiguration.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

public struct MBConfiguration: Decodable {
    public let endpoint: String
    public let domain: String
    public var installationId: String?
    public var deviceUUID: String?

    public init(
        endpoint: String,
        domain: String,
        installationId: String? = nil,
        deviceUUID: String? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.installationId = installationId
        self.deviceUUID = deviceUUID
    }

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
        self.endpoint = try values.decode(String.self, forKey: .endpoint)
        self.domain = try values.decode(String.self, forKey: .domain)
        do {
            let value = try values.decode(String.self, forKey: .installationId)
            if !value.isEmpty {
                self.installationId = value
            }
        }
        do {
            let value = try values.decode(String.self, forKey: .deviceUUID)
            if !value.isEmpty {
                self.deviceUUID = value
            }
        }
    }
}
