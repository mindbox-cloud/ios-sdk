//
//  InternalTargetingChecker.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 17.01.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation

struct PreparationContext {
    var segments: [String] = []
}

protocol ITargetingChecker: AnyObject {
    func prepare(targeting: ITargeting, context: inout PreparationContext) -> Void
    func check(targeting: ITargeting) -> Bool
}

class InternalTargetingChecker<T: ITargeting>: ITargetingChecker {
    func prepare(targeting: ITargeting, context: inout PreparationContext) {
        prepareInternal(targeting: targeting as! T, context: &context)
    }
    
    func prepareInternal(targeting: T, context: inout PreparationContext) -> Void {
        return
    }
    
    func check(targeting: ITargeting) -> Bool {
        return checkInternal(targeting: targeting as! T)
    }
    
    func checkInternal(targeting: T) -> Bool {
        preconditionFailure("This method must be overridden")
    }
}

final class TrueTargetingChecker: InternalTargetingChecker<TrueTargeting> {
    override func checkInternal(targeting: TrueTargeting) -> Bool {
        return true
    }
}

final class AndTargetingChecker: InternalTargetingChecker<AndTargeting> {
    override func prepareInternal(targeting: AndTargeting, context: inout PreparationContext) -> Void {
        for node in targeting.nodes {
            checkerMap[node]!(node).prepare(&context)
        }
    }
    
    override func checkInternal(targeting: AndTargeting) -> Bool {
        for node in targeting.nodes {
            if checkerMap[node]!(node).check() == false {
                return false
            }
        }
        return true
    }
}

final class OrTargetingChecker: InternalTargetingChecker<OrTargeting> {
    override func prepareInternal(targeting: OrTargeting, context: inout PreparationContext) -> Void {
        for node in targeting.nodes {
            checkerMap[node]!(node).prepare(&context)
        }
    }
    
    override func checkInternal(targeting: OrTargeting) -> Bool {
        for node in targeting.nodes {
            if checkerMap[node]!(node).check() == true {
                return true
            }
        }
        return false
    }
}

final class SegmentTargetingChecker: InternalTargetingChecker<SegmentTargeting> {
    init(checker: InAppTargetingCheckerVariablesProtocol) {
        self.checker = checker
    }
    
    private let checker: InAppTargetingCheckerVariablesProtocol
    
    override func prepareInternal(targeting: SegmentTargeting, context: inout PreparationContext) -> Void {
        context.segments.append(targeting.segmentationExternalId)
    }
    
    override func checkInternal(targeting: SegmentTargeting) -> Bool {
        let segment = checker.checkedSegmentations.first(where: { $0.segment?.ids?.externalId == targeting.segmentExternalId})
        switch targeting.kind {
        case .positive:
            return segment != nil
        case .negative:
            return segment == nil
        }
    }
}

struct CheckerFunctions {
    var prepare: (inout PreparationContext) -> Void = {(context: inout PreparationContext) in return }
    var check: () -> Bool = {() in return false}
}

var checkerMap: [Targeting: (Targeting) -> CheckerFunctions] = [
    .true(TrueTargeting()): { (T) -> CheckerFunctions in
        let trueChecker = TrueTargetingChecker()
        switch T {
        case .true(let targeting):
            return CheckerFunctions { context in
                return trueChecker.prepare(targeting: targeting, context: &context)
            } check: {
                return trueChecker.check(targeting: targeting)
            }
        default:
            return CheckerFunctions()
        }
    },
    
    .and(AndTargeting(nodes: [])): { (T) -> CheckerFunctions in
        let andChecker = AndTargetingChecker()
        switch T {
        case .and(let targeting):
            return CheckerFunctions { context in
                return andChecker.prepare(targeting: targeting, context: &context)
            } check: {
                return andChecker.check(targeting: targeting)
            }
        default:
            return CheckerFunctions()
        }
    },
    
    .or(OrTargeting(nodes: [])): { (T) -> CheckerFunctions in
        let orChecker = OrTargetingChecker()
        switch T {
        case .or(let targeting):
            return CheckerFunctions { context in
                return orChecker.prepare(targeting: targeting, context: &context)
            } check: {
                return orChecker.check(targeting: targeting)
            }
        default:
            return CheckerFunctions()
        }
    },
    
    .segment(SegmentTargeting(
        kind: .negative, segmentationInternalId: "",
        segmentationExternalId: "",
        segmentExternalId: "")): { (T) -> CheckerFunctions in
            let segmentChecker = SegmentTargetingChecker(checker: InAppTargetingChecker())
            switch T {
            case .segment(let targeting):
                return CheckerFunctions { context in
                    return segmentChecker.prepare(targeting: targeting, context: &context)
                } check: {
                    return segmentChecker.check(targeting: targeting)
                }
            default:
                return CheckerFunctions()
            }
        },
]
