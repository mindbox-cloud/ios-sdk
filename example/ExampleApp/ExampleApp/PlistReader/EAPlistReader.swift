//
//  EAPlistReader.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/13/24.
//

import Foundation

fileprivate enum Constants {
    static let plistName: String = "ExampleApp-Info"
    static let plistType: String = "plist"
    
    static let plistDomain: String = "Domain"
    static let plistEndpoint: String = "Endpoint"
    
    static let plistOperationSystemName: String = "Operation system name"
}

final class EAPlistReader {
    private func serializeBundleData() -> [String : Any] {
        let url = bundleUrl
        do {
            let data = try Data(contentsOf: url)
            guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                fatalError("Couldn't serialize file '\(Constants.plistName).\(Constants.plistType)'")
            }
            
            return dictionary
        } catch {
            fatalError("Couldn't find data in '\(Constants.plistName).\(Constants.plistType)'")
        }
    }
    
    private var bundleUrl: URL {
        get {
            guard let url = Bundle.main.url(forResource: Constants.plistName, withExtension: Constants.plistType) else {
                fatalError("Couldn't find file `\(Constants.plistName).\(Constants.plistType)`")
            }
            
            return url
        }
    }
}

// MARK: - PlistReader

extension EAPlistReader: PlistReader {
    var endpoint: String {
        let dictionary = serializeBundleData()
        
        guard let endpointValue = dictionary[Constants.plistEndpoint] as? String else {
            fatalError("Couldn't file value '\(Constants.plistEndpoint)'")
        }
        
        return endpointValue
    }
    
    var domain: String {
        let dictionary = serializeBundleData()
        
        guard let domainValue = dictionary[Constants.plistDomain] as? String else {
            fatalError("Couldn't fine value '\(Constants.plistDomain)'")
        }
        
        return domainValue
    }
}

// MARK: - PlistReaderOperation

extension EAPlistReader: PlistReaderOperation {
    var operationSystemName: String {
        let dictionary = serializeBundleData()
        
        guard let operationValue = dictionary[Constants.plistOperationSystemName] as? String else {
            fatalError("Couldn't fine value '\(Constants.plistOperationSystemName)'")
        }
        
        return operationValue
    }
}
