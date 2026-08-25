//
//  InappFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

/// The config's in-apps as models, settled once per applied config. Nothing that changes while that
/// config is live belongs here — frequency, priority and targeting are computed by every pass.
struct ConfigCandidates {

    let renderable: [InApp]

    /// `renderable` minus the in-apps the device's A/B branch drops.
    let inPool: [InApp]

    static let empty = ConfigCandidates(renderable: [], inPool: [])
}

/// The selection's view of the config: which in-apps are valid at all, and which of them a given
/// path — trigger, place, page, direct call — may consider. Every path starts from the same
/// `ConfigCandidates`, built once per applied config, and narrows it by what changes at runtime.
protocol InappFilterProtocol {

    /// Turns a config into the models every path narrows: the version range, the form rebuild, the
    /// A/B pool. Called once per applied config — the result holds for as long as that config does.
    func candidates(from response: ConfigResponse) -> ConfigCandidates

    /// The trigger path's candidates: in-apps an overlay can show, minus the direct-call-only ones
    /// and those the frequency already spent — in priority order.
    func filterForTrigger(in candidates: ConfigCandidates) -> [InApp]

    /// The candidates a block at `place` could show, in priority order. The trigger chain with one
    /// step swapped: "is this addressed to this place" instead of "can this be shown over the screen".
    func filter(place: String, in candidates: ConfigCandidates) -> [InApp]

    /// Every valid in-app with a variant for `place` — the A/B pool and the frequency not applied. The
    /// place is a compatibility filter, and the funnel wants everyone who could have shown here.
    func inapps(addressedTo place: String, in candidates: ConfigCandidates) -> [InApp]

    /// The in-apps out of `ids` a page may draw, before targeting. The trigger chain minus the
    /// direct-call cut — that one would drop exactly the in-apps a page is made of. In the order asked,
    /// duplicates kept: the page gets back exactly what it asked about.
    func filter(requestedIds ids: [String], in candidates: ConfigCandidates) -> [InApp]

    /// The in-app behind `id`, with no restriction checked — not the frequency, not the display
    /// conditions, not the A/B pool: an in-app the page has already offered has to open, and every
    /// one of those checks is a way for it to open into nothing. `nil` — no valid in-app under this id.
    func filter(id: String, in candidates: ConfigCandidates) -> InApp?

    /// The valid in-apps wired to `event`'s operation, with nothing else checked — the A/B pool
    /// included, so the targeting catch-up speaks for in-apps a show would never pick.
    /// Empty when the event is missing or no in-app listens to its operation.
    func filterInappsByOperation(event: ApplicationEvent?,
                                 operationInapps: [String: Set<String>],
                                 in candidates: ConfigCandidates) -> [InApp]

    /// Keeps only in-apps with at least one variant an overlay can show. A pure-embedded in-app
    /// gets its content by place instead, so it has no business on an overlay path or in the
    /// targeting catch-up (in sync with Android).
    func filterOutNonOverlayInapps(_ inapps: [InApp]) -> [InApp]

    /// `filterInappsByOperation` narrowed the way the trigger path narrows: the operation's in-apps
    /// that are actually showable right now — A/B pool, overlay variant, direct call, frequency, priority.
    func filterInappsByOperationForShow(event: ApplicationEvent?,
                                        operationInapps: [String: Set<String>],
                                        in candidates: ConfigCandidates) -> [InApp]

    /// The overlay path's targeting pass: keeps the targeted in-apps, each paired with its first
    /// overlay-presentable variant.
    func filterInappsByTargeting(inapps: [InApp], targetingChecker: InAppTargetingCheckerProtocol) -> [InAppTransitionData]

    /// The same targeting pass for callers that render something else: `pickVariant` names the
    /// variant the caller is going to draw, `nil` skips the candidate. One check, however many
    /// paths ask it — a page and a trigger disagreeing about who is targeted would be a defect
    /// nobody could explain.
    func filterInappsByTargeting(inapps: [InApp],
                                 targetingChecker: InAppTargetingCheckerProtocol,
                                 pickVariant: (InApp) -> MindboxFormVariant?) -> [InAppTransitionData]
}

final class InappsFilterService: InappFilterProtocol {

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

    func candidates(from response: ConfigResponse) -> ConfigCandidates {
        let renderable = renderableInapps(from: response.inapps?.elements)
        // Safe to cache: the device UUID it hashes is written during SDK initialization, before
        // in-apps start, and never changes afterwards.
        let inPool = filterInappsByABTests(response.abtests, responseInapps: renderable)

        return ConfigCandidates(renderable: renderable, inPool: inPool)
    }

    func filterForTrigger(in candidates: ConfigCandidates) -> [InApp] {
        applyPostABFilters(filterOutNonOverlayInapps(candidates.inPool))
    }

    func filter(place: String, in candidates: ConfigCandidates) -> [InApp] {
        filterInappsForPlace(place, inapps: candidates.inPool)
    }

    func inapps(addressedTo place: String, in candidates: ConfigCandidates) -> [InApp] {
        filterInappsByPlace(place, inapps: candidates.renderable)
    }

    func filter(requestedIds ids: [String], in candidates: ConfigCandidates) -> [InApp] {
        let asked = Set(ids)

        let missing = asked.subtracting(candidates.renderable.map(\.id))
        if !missing.isEmpty {
            Logger.common(message: "[InappsFilterService] The page asked about in-app(s) this SDK cannot render: [\(missing.sorted().joined(separator: ", "))]",
                          level: .debug, category: .inAppMessages)
        }

        let requested = ids.compactMap { id in candidates.inPool.first { $0.id == id } }
        return applyShowabilityFilters(filterOutNonOverlayInapps(requested))
    }

    func filter(id: String, in candidates: ConfigCandidates) -> InApp? {
        let inapp = candidates.renderable.first { $0.id == id }

        if inapp == nil {
            Logger.common(message: "[InappsFilterService] No in-app with id \(id) this SDK can render.",
                          level: .error, category: .inAppMessages)
        }

        return inapp
    }

    /// Version range first: the same id appears in a config once per SDK version range, so matching
    /// on the id alone can pick the copy meant for a different SDK.
    private func renderableInapps(from inapps: [InAppDTO]?) -> [InApp] {
        guard let inapps = inapps else {
            Logger.common(message: "Received nil for in-apps. Returning an empty array.", level: .debug, category: .inAppMessages)
            return []
        }

        let versionedInapps = filterInappsBySDKVersion(inapps)
        Logger.common(message: "Processing \(versionedInapps.count) in-app(s).", level: .debug, category: .inAppMessages)
        return filterValidInAppMessages(versionedInapps)
    }

    func filterInappsByOperation(event: ApplicationEvent?,
                                 operationInapps: [String: Set<String>],
                                 in candidates: ConfigCandidates) -> [InApp] {
        inappsListening(to: event, operationInapps: operationInapps, among: candidates.renderable)
    }

    func filterInappsByOperationForShow(event: ApplicationEvent?,
                                        operationInapps: [String: Set<String>],
                                        in candidates: ConfigCandidates) -> [InApp] {
        let inPool = inappsListening(to: event, operationInapps: operationInapps, among: candidates.inPool)
        return applyPostABFilters(filterOutNonOverlayInapps(inPool))
    }

    private func inappsListening(to event: ApplicationEvent?,
                                 operationInapps: [String: Set<String>],
                                 among inapps: [InApp]) -> [InApp] {
        guard let event = event,
              let inappIDS = operationInapps[event.name] else {
            Logger.common(message: "[InappsFilterService] No operation inapps for event. Return empty array", level: .debug, category: .inAppMessages)
            return []
        }

        return inapps.filter { inappIDS.contains($0.id) }
    }

    func filterInappsByTargeting(inapps: [InApp], targetingChecker: InAppTargetingCheckerProtocol) -> [InAppTransitionData] {
        filterInappsByTargeting(inapps: inapps, targetingChecker: targetingChecker) { inapp in
            inapp.form.variants.first(where: { $0.isOverlayPresentable })
        }
    }

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
                    warnIfNoPassCanReach(inappModel)
                    filteredInapps.append(inappModel)
                }
            } catch {
                Logger.common(message: "In-app [ID:] \(inapp.id)\n[Error]: \(error)", level: .error, category: .inAppMessages)
            }
        }

        Logger.common(message: "Filtering process completed. \(filteredInapps.count) valid in-app(s) found.", level: .debug, category: .inAppMessages)
        return filteredInapps
    }

    /// A direct-call in-app is cut from every pass before its targeting is asked, and a page's question
    /// carries no event — so an event-only targeting on it never passes and never vouches. Only a direct
    /// call opens such an in-app; the setting is almost certainly a mistake, in sync with Android.
    private func warnIfNoPassCanReach(_ inapp: InApp) {
        guard inapp.displayConditions == .directCall, inapp.targeting.requiresEvent else { return }

        Logger.common(message: "[InappsFilterService] In-app \(inapp.id) is direct-call only but targeted by an event: no pass will show it or vouch for it, only a direct call opens it. Check the campaign.",
                      level: .error, category: .inAppMessages)
    }

    private func createFrequencyValidator() -> InappFrequencyValidator {
        InappFrequencyValidator(persistenceStorage: persistenceStorage)
    }

    /// The overlay lock and the delayed queue are never asked here; the shared show budgets are
    /// asked later, on the winner.
    func filterInappsForPlace(_ place: String, inapps: [InApp]) -> [InApp] {
        applyPostABFilters(filterInappsByPlace(place, inapps: inapps))
    }

    private func applyPostABFilters(_ inapps: [InApp]) -> [InApp] {
        applyShowabilityFilters(filterOutDirectCallInapps(inapps))
    }

    private func applyShowabilityFilters(_ inapps: [InApp]) -> [InApp] {
        sortInappsByPriority(filterInappsByAlreadyShown(inapps))
    }

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
