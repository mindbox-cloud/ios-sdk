//
//  ImageFormatTests.swift
//  MindboxNotificationsTests
//
//  Created by Sergei Semko on 6/16/26.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Testing
import Foundation
import UserNotifications
@testable import MindboxNotifications

@Suite("ImageFormat", .tags(.notifications, .imageFormat))
struct ImageFormatTests {

    @Test("Detects the format from the leading magic byte", arguments: [
        UInt8(0x89): ImageFormat.png,
        0xFF: .jpg,
        0x47: .gif
    ])
    func detectsFormatFromFirstByte(firstByte: UInt8, expected: ImageFormat) {
        let data = Data([firstByte, 0x00, 0x01])
        #expect(ImageFormat(data) == expected)
        #expect(ImageFormat.get(from: data) == expected)
    }

    @Test("Returns nil for an unrecognized leading byte", arguments: [
        UInt8(0x00), 0x42, 0x7F, 0xAB, 0xCC
    ])
    func returnsNilForUnknownByte(firstByte: UInt8) {
        let data = Data([firstByte, 0x10])
        #expect(ImageFormat(data) == nil)
        #expect(ImageFormat.get(from: data) == nil)
    }

    @Test("Returns nil for empty data")
    func returnsNilForEmptyData() {
        #expect(ImageFormat(Data()) == nil)
        #expect(ImageFormat.get(from: Data()) == nil)
    }

    @Test("Only the first byte determines the format")
    func onlyFirstByteMatters() {
        #expect(ImageFormat(Data([0x89, 0xFF, 0x47, 0x00])) == .png)
    }

    @Test("A GIF attachment asks for frame 0 as its thumbnail, so the collapsed push shows the first frame")
    func gifThumbnailIsFirstFrame() {
        let options = ImageFormat.gif.attachmentOptions
        #expect(options?[UNNotificationAttachmentOptionsThumbnailTimeKey] as? Int == 0)
    }

    @Test("PNG and JPG attachments keep the system default thumbnail", arguments: [ImageFormat.png, .jpg])
    func staticFormatsCarryNoAttachmentOptions(format: ImageFormat) {
        #expect(format.attachmentOptions == nil)
    }

    @Test("extension equals the raw value", arguments: [
        ImageFormat.png: "png",
        .jpg: "jpg",
        .gif: "gif"
    ])
    func extensionMatchesRawValue(format: ImageFormat, expected: String) {
        #expect(format.extension == expected)
        #expect(format.rawValue == expected)
    }
}
