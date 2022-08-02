//
//  PasteboardUUIDDebugServiceTest.swift
//  MindboxTests
//
//  Created by Aleksandr Svetilov on 02.08.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
import XCTest
@testable import Mindbox

final class PasteboardUUIDDebugServiceTest: XCTestCase {

    func testCopiesUUIDInPasteboardOnFiveConsecutiveBecomeActiveNotifications() {
        let sut = makeSUT()
        let testUUID = "some random string"
        sut.service.start(with: testUUID)
        for _ in 0..<5 {
            sut.dateProvider.date = Date()
            sut.mockCenter.post(
                name: UIApplication.didBecomeActiveNotification,
                object: nil,
                userInfo: nil
            )
        }

        XCTAssertEqual(sut.mockPasteboard.string, testUUID)
    }

    private func makeSUT() -> (
        service: UUIDDebugService,
        mockCenter: MockNotificationCenter,
        mockPasteboard: UIPasteboard,
        dateProvider: MockDateProvider
    ) {
        let mockDate = MockDateProvider()
        mockDate.date = Date()
        let mockCenter = MockNotificationCenter()
        let service = PasteboardUUIDDebugService(
            notificationCenter: mockCenter,
            currentDateProvider: { return mockDate.date },
            pasteboard: UIPasteboard.general
        )
        return (service, mockCenter, UIPasteboard.general, mockDate)
    }
}
