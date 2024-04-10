//
//  InappFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InappFilterProtocol {
    func filter(inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp]
    var validInapps: [InApp] { get }
    var shownInAppsIds: Set<String> { get }
}

final class InappsFilterService: InappFilterProtocol {
    
    var validInapps: [InApp] = []
    var shownInAppsIds: Set<String> = []
    
    private let persistenceStorage: PersistenceStorage
    private let abTestDeviceMixer: ABTestDeviceMixer
    private let variantsFilter: VariantFilterProtocol
    private let sdkVersionValidator: SDKVersionValidator

    init(persistenceStorage: PersistenceStorage, abTestDeviceMixer: ABTestDeviceMixer, variantsFilter: VariantFilterProtocol, sdkVersionValidator: SDKVersionValidator) {
        self.persistenceStorage = persistenceStorage
        self.abTestDeviceMixer = abTestDeviceMixer
        self.variantsFilter = variantsFilter
        self.sdkVersionValidator = sdkVersionValidator
    }
    
    func filter(inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp] {
        guard var inapps = inapps else {
            Logger.common(message: "Received nil for in-apps. Returning an empty array.", level: .debug, category: .inAppMessages)
            return []
        }
        
        inapps = filterInappsBySDKVersion(inapps)
        Logger.common(message: "Processing \(inapps.count) in-app(s).", level: .debug, category: .inAppMessages)
        let validInapps = filterValidInAppMessages(inapps)
        let filteredByABTestInapps = filterInappsByABTests(abTests, responseInapps: validInapps)
        let filteredByAlreadyShown = filterInappsByAlreadyShown(filteredByABTestInapps)
        
        return filteredByAlreadyShown
    }
}

// MARK: - Private methods
private extension InappsFilterService {
    func filterInappsBySDKVersion(_ inapps: [InAppDTO]) -> [InAppDTO] {
        let inapps = inapps

        let filteredInapps = inapps.filter {
            let minVersionValid = $0.sdkVersion.min.map { $0 <= Constants.Versions.sdkVersionNumeric } ?? false
            let maxVersionValid = $0.sdkVersion.max.map { $0 >= Constants.Versions.sdkVersionNumeric } ?? true
            
            return minVersionValid && maxVersionValid
        }

        return filteredInapps
    }
    
    func filterValidInAppMessages(_ inapps: [InAppDTO]) -> [InApp] {
        var filteredInapps: [InApp] = []
        for inapp in inapps {
            do {
                let variants = try variantsFilter.filter(inapp.form.variants)
                if !variants.isEmpty {
                    let formModel = InAppForm(variants: variants)
                    let inappModel = InApp(id: inapp.id,
                                           sdkVersion: inapp.sdkVersion,
                                           targeting: inapp.targeting, 
                                           frequency: inapp.frequency,
                                           form: formModel)
                    filteredInapps.append(inappModel)
                }
            } catch {
                Logger.common(message: "In-app [ID:] \(inapp.id)\n[Error]: \(error)", level: .error, category: .inAppMessages)
            }
        }
        
        Logger.common(message: "Filtering process completed. \(filteredInapps.count) valid in-app(s) found.", level: .debug, category: .inAppMessages)
        validInapps = filteredInapps
        return filteredInapps
    }
    
    func filterInappsByABTests(_ abTests: [ABTest]?, responseInapps: [InApp]?) -> [InApp] {
        let responseInapps = responseInapps ?? []
        guard let abTests = abTests, !abTests.isEmpty else {
            return responseInapps
        }
        
        var result: [InApp] = responseInapps
        
        for abTest in abTests {
            guard let uuid = UUID(uuidString: persistenceStorage.deviceUUID ?? "" ),
                  let salt = abTest.salt,
                  let variants = abTest.variants else {
                continue
            }
            
            let hashValue = try? abTestDeviceMixer.modulusGuidHash(identifier: uuid, salt: salt)
            
            guard let hashValue = hashValue else {
                continue
            }
            
            Logger.common(message: "[Hash Value]: \(hashValue) for [UUID]: \(persistenceStorage.deviceUUID ?? "nil")")
            Logger.common(message: "[AB-test ID]: \(abTest.id)")
            
            var allInappsInVariantsExceptCurrentBranch: [String] = []
            
            for variant in variants {
                if let objects = variant.objects {
                    for object in objects {
                        if object.kind == .all {
                            responseInapps.forEach( {
                                allInappsInVariantsExceptCurrentBranch.append($0.id)
                            })
                        } else {
                            allInappsInVariantsExceptCurrentBranch += object.inapps ?? []
                        }
                    }
                }
            }
            
            var setInapps = Set(allInappsInVariantsExceptCurrentBranch)
            
            for variant in variants {
                if let modulus = variant.modulus, let objects = variant.objects, let upper = modulus.upper {
                    let range = modulus.lower..<upper
                    if range.contains(hashValue) {
                        Logger.common(message: "[AB-test branch ID]: \(variant.id)")
                        for object in objects {
                            if object.kind == .all {
                                setInapps.removeAll()
                            } else if let inapps = object.inapps {
                                setInapps.subtract(inapps)
                            }
                        }
                    }
                }
            }
            
            let currentResult = responseInapps.filter { !setInapps.contains($0.id) }
            result = result.filter { currentResult.contains($0) }
        }
        
        let ids = result.map { $0.id }
        Logger.common(message: "Filtered in-app IDs after AB-filter based on UUID branch: [\(ids.joined(separator: ", "))]")
        
        return result
    }
    
    func filterInappsByAlreadyShown(_ inapps: [InApp]) -> [InApp] {
        shownInAppsIds = Set(persistenceStorage.shownInAppsIds ?? [])
        Logger.common(message: "Shown in-apps ids: [\(shownInAppsIds)]", level: .info, category: .inAppMessages)
        let filteredInapps = inapps.filter {
            sdkVersionValidator.isValid(item: $0.sdkVersion)
            && !shownInAppsIds.contains($0.id)
        }

        return filteredInapps
    }
}
