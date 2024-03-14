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
    func filter(inapps: [InAppDTO]?) -> [InApp]
}

final class InappsFilterService: InappFilterProtocol {
    private let variantsFilter: VariantFilterProtocol

    init(variantsFilter: VariantFilterProtocol) {
        self.variantsFilter = variantsFilter
    }
    
    func filter(inapps: [InAppDTO]?) -> [InApp] {
        guard var inapps = inapps else {
            Logger.common(message: "Received nil for in-apps. Returning an empty array.", level: .debug, category: .inAppMessages)
            return []
        }
        
        inapps = filterInappsBySDKVersion(inapps)
        
        Logger.common(message: "Processing \(inapps.count) in-app(s).", level: .debug, category: .inAppMessages)
        
        var filteredInapps: [InApp] = []
        for inapp in inapps {
            do {
                let variants = try variantsFilter.filter(inapp.form.variants)
                if !variants.isEmpty {
                    let formModel = InAppForm(variants: variants)
                    let inappModel = InApp(id: inapp.id,
                                           sdkVersion: inapp.sdkVersion,
                                           targeting: inapp.targeting,
                                           form: formModel)
                    filteredInapps.append(inappModel)
                }
            } catch {
                Logger.common(message: "In-app [ID:] \(inapp.id)\n[Error]: \(error)", level: .error, category: .inAppMessages)
            }
        }
        
        Logger.common(message: "Filtering process completed. \(filteredInapps.count) valid in-app(s) found.", level: .debug, category: .inAppMessages)
        return filteredInapps
    }
    
    func filterInappsBySDKVersion(_ inapps: [InAppDTO]) -> [InAppDTO] {
        let inapps = inapps

        let filteredInapps = inapps.filter {
            let minVersionValid = $0.sdkVersion.min.map { $0 <= Constants.Versions.sdkVersionNumeric } ?? false
            let maxVersionValid = $0.sdkVersion.max.map { $0 >= Constants.Versions.sdkVersionNumeric } ?? true
            
            return minVersionValid && maxVersionValid
        }

        return filteredInapps
    }
}
