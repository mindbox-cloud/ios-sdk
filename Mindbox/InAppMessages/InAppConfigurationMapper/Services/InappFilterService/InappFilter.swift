//
//  InappFilter.swift
//  Mindbox
//
//  Created by vailence on 07.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

struct ConfigCandidates {

    let renderable: [InApp]

    let inPool: [InApp]

    static let empty = ConfigCandidates(renderable: [], inPool: [])
}

protocol InappFilterProtocol {

    func candidates(from response: ConfigResponse) -> ConfigCandidates

    func filterForTrigger(in candidates: ConfigCandidates) -> [InApp]

    func filter(place: String, in candidates: ConfigCandidates) -> [InApp]

    func inapps(addressedTo place: String, in candidates: ConfigCandidates) -> [InApp]

    func inapps(askedAbout ids: [String], in candidates: ConfigCandidates) -> [InApp]

    func filter(requestedIds ids: [String], in candidates: ConfigCandidates) -> [InApp]

    func filter(id: String, in candidates: ConfigCandidates) -> InApp?

    func filterInappsByOperation(event: ApplicationEvent?,
                                 operationInapps: [String: Set<String>],
                                 in candidates: ConfigCandidates) -> [InApp]

    func filterOutNonOverlayInapps(_ inapps: [InApp]) -> [InApp]

    func filterInappsByOperationForShow(event: ApplicationEvent?,
                                        operationInapps: [String: Set<String>],
                                        in candidates: ConfigCandidates) -> [InApp]

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
        // Safe to cache: deviceUUID is written during SDK initialization, before in-apps start.
        let inPool = filterInappsByABTests(response.abtests, responseInapps: renderable)

        return ConfigCandidates(renderable: renderable, inPool: inPool)
    }

    func filterForTrigger(in candidates: ConfigCandidates) -> [InApp] {
        applyPostABFilters(filterOutNonOverlayInapps(candidates.inPool))
    }

    func filter(place: String, in candidates: ConfigCandidates) -> [InApp] {
        applyPostABFilters(filterInappsByPlace(place, inapps: candidates.inPool))
    }

    func inapps(addressedTo place: String, in candidates: ConfigCandidates) -> [InApp] {
        filterInappsByPlace(place, inapps: candidates.renderable)
    }

    func inapps(askedAbout ids: [String], in candidates: ConfigCandidates) -> [InApp] {
        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return candidates.renderable.first { $0.id == id }
        }
    }

    func filter(requestedIds ids: [String], in candidates: ConfigCandidates) -> [InApp] {
        let asked = Set(ids)

        let missing = asked.subtracting(candidates.renderable.map(\.id))
        if !missing.isEmpty {
            Logger.common(message: "[InappsFilterService] The page asked about in-app(s) this SDK cannot render: [\(missing.sorted().joined(separator: ", "))]",
                          level: .debug, category: .inAppMessages)
        }

        let requested = ids.compactMap { id in candidates.inPool.first { $0.id == id } }
        return filterInappsByAlreadyShown(filterOutNonOverlayInapps(requested))
    }

    func filter(id: String, in candidates: ConfigCandidates) -> InApp? {
        let inapp = candidates.renderable.first { $0.id == id }

        if inapp == nil {
            Logger.common(message: "[InappsFilterService] No in-app with id \(id) this SDK can render.",
                          level: .error, category: .inAppMessages)
        }

        return inapp
    }

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

    private func warnIfNoPassCanReach(_ inapp: InApp) {
        guard inapp.displayConditions == .directCall, inapp.targeting.requiresEvent else { return }

        Logger.common(message: "[InappsFilterService] In-app \(inapp.id) is direct-call only but targeted by an event: no pass will show it or vouch for it, only a direct call opens it. Check the campaign.",
                      level: .error, category: .inAppMessages)
    }

    private func createFrequencyValidator() -> InappFrequencyValidator {
        InappFrequencyValidator(persistenceStorage: persistenceStorage)
    }

    private func applyPostABFilters(_ inapps: [InApp]) -> [InApp] {
        sortInappsByPriority(filterInappsByAlreadyShown(filterOutDirectCallInapps(inapps)))
    }

    func filterInappsByPlace(_ place: String, inapps: [InApp]) -> [InApp] {
        inapps.filter { inapp in inapp.form.variants.contains { $0.placeSystemName == place } }
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
