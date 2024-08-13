//
//  MindboxNotificationContentTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 8/13/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import MindboxNotifications

@available(iOS 13.0, *)
final class MindboxNotificationContentTests: XCTestCase {

    var service: MindboxNotificationService! // MindboxNotificationContentProtocol
    var mockViewController: UIViewController!
    var mockExtensionContext: NSExtensionContext!
    var mockNotificationRequest: UNNotificationRequest!
    
    override func setUp() {
        super.setUp()
        service = MindboxNotificationService()
        mockViewController = UIViewController()
        mockExtensionContext = MockExtensionContext()
        
        let aps: [AnyHashable: Any] = [
            "mutable-content": 1,
            "alert": [
                "title": "Test title",
                "body": "Test description"
            ],
            "content-available": 1,
            "sound": "default"
        ]
        
        let userInfo: [AnyHashable: Any] = [
            "clickUrl": "https://mindbox.ru/",
            "payload": "{\n  \"payload\": \"data\"\n}",
            "uniqueKey": "4cccb64d-ba46-41eb-9699-3a706f2b910b",
            "imageUrl": "https://mobpush-images.mindbox.ru/Mpush-test/63/5933f4cd-47e3-4317-9237-bc5aad291aa9.png",
            "buttons": [
                [
                    "url": "https://developers.mindbox.ru/docs/mindbox-sdk",
                    "text": "Documentation",
                    "uniqueKey": "1b112bcd-5eae-4914-8842-d77198466466"
                ],
                [
                    "url": "https://google.com",
                    "text": "Button #1",
                    "uniqueKey": "cff05f38-6df4-4a10-9859-ea3bf0a65068"
                ]
            ],
            "aps": aps
        ]
        
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = "Test title"
        content.body = "Test description"
        
        let image = UIImage(systemName: "star")!
        let imageData = image.pngData()!
        let tempDirectory = FileManager.default.temporaryDirectory
        let imageFileURL = tempDirectory.appendingPathComponent("testImage.png")
        
        try! imageData.write(to: imageFileURL)
        let notificationAttachment = try! UNNotificationAttachment(identifier: "identifier", url: imageFileURL, options: nil)
        
        content.attachments.append(notificationAttachment)
        
        mockNotificationRequest = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
    }
    
    override func tearDown() {
        service = nil
        mockViewController = nil
        mockExtensionContext = nil
        mockNotificationRequest = nil
        super.tearDown()
    }

    func testDidReceiveFromMindboxNotificationContentProtocol() {
        let mockNotification = MockUNNotification(request: mockNotificationRequest)
        
        XCTAssertFalse(mockNotification.request.content.attachments.isEmpty)
        
        service.didReceive(notification: mockNotification, 
                           viewController: mockViewController,
                           extensionContext: mockExtensionContext)
        
        XCTAssertEqual(service.viewController, mockViewController)
        XCTAssertEqual(service.context, mockExtensionContext)
        
        XCTAssertFalse(service.context!.notificationActions.isEmpty)
        XCTAssertEqual(service.context!.notificationActions.count, 2)
        
        let actionTitles = service.context!.notificationActions.map { $0.title }
        XCTAssertTrue(actionTitles.contains("Documentation"))
        XCTAssertTrue(actionTitles.contains("Button #1"))
        
        let imageView = mockViewController.view.subviews.first { $0 is UIImageView } as? UIImageView
        XCTAssertNotNil(imageView, "The UIImageView should be added to the ViewController")
    }
}

@available(iOS 12.0, *)
fileprivate class MockExtensionContext: NSExtensionContext {
    var actions: [UNNotificationAction] = []
    
    override var notificationActions: [UNNotificationAction] {
        get {
            return actions
        }
        set {
            actions = newValue
        }
    }
}


@available(iOS 12.0, *)
fileprivate class MockUNNotification: UNNotification {
    private let mockRequest: UNNotificationRequest
    
    init(request: UNNotificationRequest) {
        self.mockRequest = request
        
        let data = try! NSKeyedArchiver.archivedData(withRootObject: request, requiringSecureCoding: true)
        
        let coder = try! NSKeyedUnarchiver(forReadingFrom: data)
        
        super.init(coder: coder)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var request: UNNotificationRequest {
        return mockRequest
    }
}
