//
//  InjectABTestUtilities.swift
//  Mindbox
//
//  Created by vailence on 21.06.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation

import abmixer

extension MBContainer {
    func registerABTestUtilities() -> Self {
        register(CustomerAbMixer.self, scope: .transient) {
            CustomerAbMixerCompanion().impl()
        }

        register(ABTestVariantsValidator.self, scope: .transient) {
            ABTestVariantsValidator()
        }

        register(ABTestValidator.self, scope: .transient) {
            let sdkVersionValidator = DI.injectOrFail(SDKVersionValidator.self)
            let abTestVariantValidator = DI.injectOrFail(ABTestVariantsValidator.self)
            return ABTestValidator(sdkVersionValidator: sdkVersionValidator, variantsValidator: abTestVariantValidator)
        }

        return self
    }
}
