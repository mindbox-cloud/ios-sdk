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
        guard let inapps = inapps else {
            Logger.common(message: "Received nil for in-apps. Returning an empty array.", level: .debug, category: .inAppMessages)
            return []
        }
        
        Logger.common(message: "Processing \(inapps.count) in-app(s).", level: .debug, category: .inAppMessages)
        
        var filteredInapps: [InApp] = []
        for inapp in inapps {
            do {
                if let variants = try variantsFilter.filter(inapp.form.variants), !variants.isEmpty {
                    let formModel = InAppForm(variants: variants)
                    let inappModel = InApp(id: inapp.id,
                                           sdkVersion: inapp.sdkVersion,
                                           targeting: inapp.targeting,
                                           form: formModel)
                    filteredInapps.append(inappModel)
                }
            } catch {
                print("Error filtering variants for in-app with id \(inapp.id): \(error.localizedDescription)")
            }
        }
        
        Logger.common(message: "Filtering process completed. \(filteredInapps.count) valid in-app(s) found.", level: .debug, category: .inAppMessages)
        return filteredInapps
    }
}
