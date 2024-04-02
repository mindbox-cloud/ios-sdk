//
//  CheckerFactory.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 29.03.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import Foundation

protocol CheckerFactory {
    func makeChecker(for targetType: Targeting) -> CheckerFunctions
}

final class TrueTargetingFactory: CheckerFactory {
    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .true(targeting) = targetType else { return checkerFunctions }
        let trueChecker = TrueTargetingChecker()
        return CheckerFunctions(
            prepare: { context in trueChecker.prepare(targeting: targeting, context: &context) },
            check: { trueChecker.check(targeting: targeting) }
        )
    }
}

final class AndTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .and(targeting) = targetType else { return checkerFunctions }
        let andChecker = AndTargetingChecker()
        andChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in andChecker.prepare(targeting: targeting, context: &context) },
            check: { andChecker.check(targeting: targeting) }
        )
    }
}

final class OrTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .or(targeting) = targetType else { return checkerFunctions }
        let orChecker = OrTargetingChecker()
        orChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in orChecker.prepare(targeting: targeting, context: &context) },
            check: { orChecker.check(targeting: targeting) }
        )
    }
}

final class SegmentTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .segment(targeting) = targetType else { return checkerFunctions }
        let segmentChecker = SegmentTargetingChecker()
        segmentChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in segmentChecker.prepare(targeting: targeting, context: &context) },
            check: { segmentChecker.check(targeting: targeting) }
        )
    }
}

final class CityTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .city(targeting) = targetType else { return checkerFunctions }
        let cityChecker = CityTargetingChecker()
        cityChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in cityChecker.prepare(targeting: targeting, context: &context) },
            check: { cityChecker.check(targeting: targeting) }
        )
    }
}

final class RegionTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .region(targeting) = targetType else { return checkerFunctions }
        let regionChecker = RegionTargetingChecker()
        regionChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in regionChecker.prepare(targeting: targeting, context: &context) },
            check: { regionChecker.check(targeting: targeting) }
        )
    }
}

final class CountryTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .country(targeting) = targetType else { return checkerFunctions }
        let countryChecker = CountryTargetingChecker()
        countryChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in countryChecker.prepare(targeting: targeting, context: &context) },
            check: { countryChecker.check(targeting: targeting) }
        )
    }
}

final class CustomOperationTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .apiMethodCall(targeting) = targetType else { return checkerFunctions }
        let customOperationChecker = CustomOperationChecker()
        customOperationChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in customOperationChecker.prepare(targeting: targeting, context: &context) },
            check: { customOperationChecker.check(targeting: targeting) }
        )
    }
}

final class CategoryIDTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .viewProductCategoryId(targeting) = targetType else { return checkerFunctions }
        let categoryIDChecker = CategoryIDChecker()
        categoryIDChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in categoryIDChecker.prepare(targeting: targeting, context: &context) },
            check: { categoryIDChecker.check(targeting: targeting) }
        )
    }
}

final class CategoryIDInTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .viewProductCategoryIdIn(targeting) = targetType else { return checkerFunctions }
        let categoryIDInChecker = CategoryIDInChecker()
        categoryIDInChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in categoryIDInChecker.prepare(targeting: targeting, context: &context) },
            check: { categoryIDInChecker.check(targeting: targeting) }
        )
    }
}

final class ProductCategoryIDTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .viewProductId(targeting) = targetType else { return checkerFunctions }
        let productIDChecker = ProductIDChecker()
        productIDChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in productIDChecker.prepare(targeting: targeting, context: &context) },
            check: { productIDChecker.check(targeting: targeting) }
        )
    }
}

final class ProductSegmentTargetingFactory: CheckerFactory {
    private let checker: InAppTargetingCheckerProtocol

    init(checker: InAppTargetingCheckerProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .viewProductSegment(targeting) = targetType else { return checkerFunctions }
        let productSegmentChecker = ProductSegmentChecker()
        productSegmentChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in productSegmentChecker.prepare(targeting: targeting, context: &context) },
            check: { productSegmentChecker.check(targeting: targeting) }
        )
    }
}

final class VisitTargetingFactory: CheckerFactory {
    private let checker: TargetingCheckerPersistenceStorageProtocol

    init(checker: TargetingCheckerPersistenceStorageProtocol) {
        self.checker = checker
    }

    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .visit(targeting) = targetType else {
            return checkerFunctions
        }
        
        let visitChecker = VisitTargetingChecker()
        visitChecker.checker = checker
        return CheckerFunctions(
            prepare: { context in visitChecker.prepare(targeting: targeting, context: &context) },
            check: { visitChecker.check(targeting: targeting) }
        )
    }
}

final class PushEnabledTargetingFactory: CheckerFactory {
    func makeChecker(for targetType: Targeting) -> CheckerFunctions {
        let checkerFunctions = CheckerFunctions()
        guard case let .pushEnabled(targeting) = targetType else { return checkerFunctions }
        let pushEnabledChecker = PushEnabledTargetingChecker()
        return CheckerFunctions(
            prepare: { context in pushEnabledChecker.prepare(targeting: targeting, context: &context) },
            check: { pushEnabledChecker.check(targeting: targeting) }
        )
    }
}
