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
    func filter(place: String, inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp]
    func filter(feedIds ids: [String], inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp]
    func filter(id: String, inapps: [InAppDTO]?) -> InApp?
    func filterInappsByOperation(event: ApplicationEvent?, operationInapps: [String: Set<String>]) -> [InApp]
    func filterOutNonOverlayInapps(_ inapps: [InApp]) -> [InApp]
    func filterInappsByOperationForShow(event: ApplicationEvent?, abTests: [ABTest]?, operationInapps: [String: Set<String>]) -> [InApp]
    func filterInappsByTargeting(inapps: [InApp], targetingChecker: InAppTargetingCheckerProtocol) -> [InAppTransitionData]
    func filterInappsByTargeting(inapps: [InApp],
                                 targetingChecker: InAppTargetingCheckerProtocol,
                                 pickVariant: (InApp) -> MindboxFormVariant?) -> [InAppTransitionData]
    var validInapps: [InApp] { get }
}

final class InappsFilterService: InappFilterProtocol {

    var validInapps: [InApp] = []

    private let persistenceStorage: PersistenceStorage
    private let variantsFilter: VariantFilterProtocol
    private let sdkVersionValidator: SDKVersionValidator

    init(persistenceStorage: PersistenceStorage,
         variantsFilter: VariantFilterProtocol,
         sdkVersionValidator: SDKVersionValidator) {
        self.persistenceStorage = persistenceStorage
        self.variantsFilter = variantsFilter
        self.sdkVersionValidator = sdkVersionValidator
    }

    func filter(inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp] {
        applyCommonFilters(inapps: renderableInapps(from: inapps), abTests: abTests)
    }

    /// The candidates a block at this place could show, in priority order.
    func filter(place: String, inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp] {
        filterInappsForPlace(place, inapps: renderableInapps(from: inapps), abTests: abTests)
    }

    /// The in-apps out of `ids` a feed is allowed to draw, before targeting.
    ///
    /// The same steps the other paths run, except the direct-call one — it would drop exactly the
    /// in-apps a feed is made of. The frequency step is here like everywhere else: for the
    /// `unlimited` stories the contract prescribes it never cuts, because unlimited shows are never
    /// recorded.
    func filter(feedIds ids: [String], inapps: [InAppDTO]?, abTests: [ABTest]?) -> [InApp] {
        // The full list goes through the version and form filters first: narrowing to the asked ids
        // earlier would leave `validInapps` holding a subset, and the rest of the selection reads it.
        let renderable = renderableInapps(from: inapps)
        let asked = Set(ids)
        let requested = renderable.filter { asked.contains($0.id) }

        let missing = asked.subtracting(requested.map(\.id))
        if !missing.isEmpty {
            Logger.common(message: "[InappsFilterService] The feed asked about in-app(s) this SDK cannot render: [\(missing.sorted().joined(separator: ", "))]",
                          level: .debug, category: .inAppMessages)
        }

        let showable = filterOutNonOverlayInapps(requested)
        let inPool = filterInappsByABTests(abTests, responseInapps: showable)
        return applyShowabilityFilters(inPool)
    }

    /// The in-app behind an id, with no restriction checked — not the frequency, not the display
    /// conditions, not the A/B pool. An in-app the page has already offered has to open, and
    /// every one of those checks is a way for it to open into nothing.
    ///
    /// The version filter runs first because it is not a restriction on showing but on understanding:
    /// the same id appears more than once in a config, once per SDK version range, and matching on the
    /// id alone can pick the copy meant for a different SDK.
    func filter(id: String, inapps: [InAppDTO]?) -> InApp? {
        let inapp = renderableInapps(from: inapps).first { $0.id == id }

        if inapp == nil {
            Logger.common(message: "[InappsFilterService] No in-app with id \(id) this SDK can render.",
                          level: .error, category: .inAppMessages)
        }

        return inapp
    }

    /// Everything this SDK can make sense of: the right version range, and a form that parses. No
    /// question about whether it should be shown has been asked yet.
    private func renderableInapps(from inapps: [InAppDTO]?) -> [InApp] {
        guard let inapps = inapps else {
            Logger.common(message: "Received nil for in-apps. Returning an empty array.", level: .debug, category: .inAppMessages)
            return []
        }

        let versionedInapps = filterInappsBySDKVersion(inapps)
        Logger.common(message: "Processing \(versionedInapps.count) in-app(s).", level: .debug, category: .inAppMessages)
        return filterValidInAppMessages(versionedInapps)
    }
    
    func filterInappsByOperation(event: ApplicationEvent?, operationInapps: [String: Set<String>]) -> [InApp] {
        guard let event = event,
              let inappIDS = operationInapps[event.name] else {
            Logger.common(message: "[InappsFilterService] No operation inapps for event. Return empty array", level: .debug, category: .inAppMessages)
            return []
        }
        
        return validInapps.filter { inappIDS.contains($0.id) }
    }
    
    func filterInappsByOperationForShow(event: ApplicationEvent?, abTests: [ABTest]?, operationInapps: [String: Set<String>]) -> [InApp] {
        let inapps = filterInappsByOperation(event: event, operationInapps: operationInapps)
        return applyCommonFilters(inapps: inapps, abTests: abTests)
    }

    /// The overlay path takes the first variant that can actually be shown over the screen, not simply
    /// the first one: handing the displayer a variant that is drawn inside the host layout would mean
    /// showing nothing at all.
    func filterInappsByTargeting(inapps: [InApp], targetingChecker: InAppTargetingCheckerProtocol) -> [InAppTransitionData] {
        filterInappsByTargeting(inapps: inapps, targetingChecker: targetingChecker) { inapp in
            inapp.form.variants.first(where: { $0.isOverlayPresentable })
        }
    }

    /// Targeting is the same question on every path; which variant answers it is not. The caller says
    /// what it is going to render, so the check itself stays in one place.
    func filterInappsByTargeting(inapps: [InApp],
                                 targetingChecker: InAppTargetingCheckerProtocol,
                                 pickVariant: (InApp) -> MindboxFormVariant?) -> [InAppTransitionData] {
        var filteredInAppsByEvent: [InAppTransitionData] = []

        for inapp in inapps {
            guard targetingChecker.check(targeting: inapp.targeting) else {
                continue
            }

            if let inAppFormVariants = pickVariant(inapp) {
                let formData = InAppTransitionData(inAppId: inapp.id,
                                                   isPriority: inapp.isPriority,
                                                   delayTime: inapp.delayTime,
                                                   content: inAppFormVariants,
                                                   frequency: inapp.frequency,
                                                   tags: inapp.tags)
                filteredInAppsByEvent.append(formData)
            }
        }

        return filteredInAppsByEvent
    }
}

// MARK: - Internal methods
extension InappsFilterService {
    // FIXME: Rewrite this func in the future
    // swiftlint:disable:next cyclomatic_complexity
    func filterInappsByABTests(_ abTests: [ABTest]?, responseInapps: [InApp]?) -> [InApp] {
        let responseInapps = responseInapps ?? []
        guard let abTests = abTests, !abTests.isEmpty else {
            return responseInapps
        }

        var result: [InApp] = responseInapps
        let abTestDeviceMixer = DI.injectOrFail(ABTestDeviceMixer.self)

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
                if let modulus = variant.modulus, let objects = variant.objects {
                    let range = modulus.lower..<modulus.upper
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
        let frequencyValidator = self.createFrequencyValidator()
        let shownIds = persistenceStorage.shownDatesByInApp?.keys ?? [:].keys
        Logger.common(message: "Shown in-apps ids: [\(shownIds)]", level: .info, category: .inAppMessages)
        let filteredInapps = inapps.filter {
            let result = frequencyValidator.isValid(frequency: $0.frequency, id: $0.id)
            return result
        }

        return filteredInapps
    }
    
    func filterInappsBySDKVersion(_ inapps: [InAppDTO]) -> [InAppDTO] {
        let inapps = inapps
        let filteredInapps = inapps.filter {
            sdkVersionValidator.isValid(item: $0.sdkVersion)
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
                                           isPriority: inapp.isPriority,
                                           delayTime: inapp.delayTime,
                                           sdkVersion: inapp.sdkVersion,
                                           targeting: inapp.targeting,
                                           frequency: inapp.frequency,
                                           displayConditions: inapp.displayConditions,
                                           form: formModel,
                                           tags: inapp.tags)
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

    private func createFrequencyValidator() -> InappFrequencyValidator {
        InappFrequencyValidator(persistenceStorage: persistenceStorage)
    }

    private func applyCommonFilters(inapps: [InApp], abTests: [ABTest]?) -> [InApp] {
        let filteredByABTestInapps = filterInappsByABTests(abTests, responseInapps: inapps)
        let overlayInapps = filterOutNonOverlayInapps(filteredByABTestInapps)
        return applyPostABFilters(overlayInapps)
    }

    /// The candidates for one place in the host layout. Deliberately the same chain as the overlay path
    /// with a single step swapped: instead of "can this be shown over the screen" it asks "is this
    /// addressed to this place". Everything after that — direct call, frequency, priority — is
    /// the code the trigger path runs, not a copy of it.
    ///
    /// The one-in-app-at-a-time lock and the delayed queue belong to showing an overlay and are never
    /// asked here; the shared show budgets are asked later, on the winner.
    func filterInappsForPlace(_ place: String, inapps: [InApp], abTests: [ABTest]?) -> [InApp] {
        let filteredByABTestInapps = filterInappsByABTests(abTests, responseInapps: inapps)
        let placeInapps = filterInappsByPlace(place, inapps: filteredByABTestInapps)
        return applyPostABFilters(placeInapps)
    }

    private func applyPostABFilters(_ inapps: [InApp]) -> [InApp] {
        applyShowabilityFilters(filterOutDirectCallInapps(inapps))
    }

    /// The steps every entry point runs, whatever it started from: what the frequency still allows, in
    /// priority order. Shared rather than copied so a step added here cannot silently skip a path.
    private func applyShowabilityFilters(_ inapps: [InApp]) -> [InApp] {
        sortInappsByPriority(filterInappsByAlreadyShown(inapps))
    }

    /// Names match exactly. They are already trimmed by the variants filter, and case has to match — a
    /// case-only difference is a configuration mistake with no symptoms, so it is called out in the log
    /// rather than quietly accepted.
    func filterInappsByPlace(_ place: String, inapps: [InApp]) -> [InApp] {
        inapps.filter { inapp in
            let places = inapp.form.variants.compactMap { $0.placeSystemName }

            guard !places.isEmpty else { return false }

            if places.contains(place) {
                return true
            }

            if let sameNameOtherCase = places.first(where: { $0.lowercased() == place.lowercased() }) {
                Logger.common(message: "[InappsFilterService] In-app \(inapp.id) is set up for place '\(sameNameOtherCase)' and the block asked for '\(place)'. Place names are case-sensitive.",
                              level: .error, category: .inAppMessages)
            }

            return false
        }
    }

    /// Only in-apps that have something to show over the app's own screen belong on this path. An
    /// embedded block is drawn inside the host layout and gets its content by place instead, so it has
    /// nothing to do here — and this asks the variant what it can do rather than what it is.
    func filterOutNonOverlayInapps(_ inapps: [InApp]) -> [InApp] {
        inapps.filter { inapp in
            guard inapp.form.variants.contains(where: { $0.isOverlayPresentable }) else {
                Logger.common(message: "[InappsFilterService] In-app \(inapp.id) has no variant that can be shown over the screen. Skipping.",
                              level: .debug, category: .inAppMessages)
                return false
            }
            return true
        }
    }

    /// An in-app restricted to a direct call answers no trigger at all — not an operation, not the
    /// app start.
    func filterOutDirectCallInapps(_ inapps: [InApp]) -> [InApp] {
        inapps.filter { inapp in
            guard inapp.displayConditions != .directCall else {
                Logger.common(message: "[InappsFilterService] In-app \(inapp.id) is direct call only. Skipping.",
                              level: .debug, category: .inAppMessages)
                return false
            }
            return true
        }
    }

    func sortInappsByPriority(_ inapps: [InApp]) -> [InApp] {
        return inapps.sorted { $0.isPriority && !$1.isPriority }
    }
}
