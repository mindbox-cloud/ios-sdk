//
//  PasteboardUUIDDebugServiceTest.swift
//  MindboxTests
//
//  Created by Aleksandr Svetilov on 02.08.2022.
//

import Foundation
import XCTest
@testable import Mindbox


// Not working on iOS 16: https://developer.apple.com/forums/thread/714366

//final class PasteboardUUIDDebugServiceTest: XCTestCase {
//
//    func testCopiesUUIDInPasteboardOnFiveConsecutiveBecomeActiveNotifications() {
//        let sut = makeSUT()
//        let testUUID = "some random string"
//
//        sut.service.start(with: testUUID)
//        for _ in 0..<PasteboardUUIDDebugService.triggerNotificationCount {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//
//        XCTAssertEqual(sut.mockPasteboard.string, testUUID)
//    }
//
//    func testDoesNotCopyAnythingOnInsufficientAmountOfNotifications() {
//        let sut = makeSUT()
//        let testUUID = "some random string"
//
//        sut.service.start(with: testUUID)
//        for _ in 0..<PasteboardUUIDDebugService.triggerNotificationCount - 1 {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//
//        XCTAssertNil(sut.mockPasteboard.string)
//    }
//
//    func testResetsCountAfterTriggering() {
//        let sut = makeSUT()
//        let testUUID = "some random string"
//
//        sut.service.start(with: testUUID)
//        for _ in 0..<PasteboardUUIDDebugService.triggerNotificationCount {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//        XCTAssertEqual(sut.mockPasteboard.string, testUUID)
//        sut.mockPasteboard.items = []
//        for _ in 0..<2 {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//
//        XCTAssertNil(sut.mockPasteboard.string, testUUID)
//    }
//
//    func testResetsCountOnLongInterval() {
//        let sut = makeSUT()
//        let testUUID = "some random string"
//
//        sut.service.start(with: testUUID)
//        for _ in 0..<PasteboardUUIDDebugService.triggerNotificationCount - 1 {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//        sut.dateProvider.date = Date()
//            .addingTimeInterval(PasteboardUUIDDebugService.triggerNotificationInterval + 1)
//        sut.mockCenter.post(
//            name: PasteboardUUIDDebugService.triggerNotificationName,
//            object: nil,
//            userInfo: nil
//        )
//
//        XCTAssertNil(sut.mockPasteboard.string, testUUID)
//    }
//
//    func testDoesNotStartMoreThanOnce() {
//        let sut = makeSUT()
//        let testUUID = "some random string"
//
//        sut.service.start(with: testUUID)
//        sut.service.start(with: testUUID)
//        sut.service.start(with: testUUID)
//        for _ in 0..<2 {
//            sut.dateProvider.date = Date()
//            sut.mockCenter.post(
//                name: PasteboardUUIDDebugService.triggerNotificationName,
//                object: nil,
//                userInfo: nil
//            )
//        }
//
//        XCTAssertNil(sut.mockPasteboard.string, testUUID)
//    }
//
//    private func makeSUT() -> (
//        service: UUIDDebugService,
//        mockCenter: MockNotificationCenter,
//        mockPasteboard: UIPasteboard,
//        dateProvider: MockDateProvider
//    ) {
//        let mockDate = MockDateProvider()
//        mockDate.date = Date()
//        let mockBoard = UIPasteboard.general
//        mockBoard.items = []
//        let mockCenter = MockNotificationCenter()
//        let service = PasteboardUUIDDebugService(
//            notificationCenter: mockCenter,
//            currentDateProvider: { return mockDate.date },
//            pasteboard: mockBoard
//        )
//        return (service, mockCenter, mockBoard, mockDate)
//    }
//
//}
