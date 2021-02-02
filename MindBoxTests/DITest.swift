//
//  DITest.swift
//  MindBoxTests
//
//  Created by Mikhail Barilov on 28.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//


import XCTest
@testable import MindBox

class DITest: XCTestCase {


    override func setUp() {

        DIManager.shared.dropContainer()
        DIManager.shared.registerServices()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testOnInitCase() {

        let extractor = DIExtractor()

        let opExtractor = DIExtractorOptionals()

        XCTAssert(opExtractor.logger != nil)
        XCTAssert(opExtractor.fetchUtilities != nil)
        XCTAssert(opExtractor.configurationStorage != nil)
        XCTAssert(opExtractor.apiService != nil)
        XCTAssert(opExtractor.ambApiService != nil)
        XCTAssert(opExtractor.persistenceStorage != nil)

        extractor.persistenceStorage.apnsToken = "123"

        XCTAssert(opExtractor.persistenceStorage.apnsToken == extractor.persistenceStorage.apnsToken)

    }

    class DIExtractor {
        @Injected var logger: ILogger
        @Injected var fetchUtilities: IFetchUtilities
        @Injected var configurationStorage: IConfigurationStorage
        @Injected var apiService: APIService
        @Injected var ambApiService: IMindBoxAPIService
        @Injected var persistenceStorage: PersistenceStorage

        init() {
        }
    }

    class DIExtractorOptionals {
        @InjectedOptional var logger: ILogger!
        @InjectedOptional var fetchUtilities: IFetchUtilities!
        @InjectedOptional var configurationStorage: IConfigurationStorage!
        @InjectedOptional var apiService: APIService!
        @InjectedOptional var ambApiService: IMindBoxAPIService!
        @InjectedOptional var persistenceStorage: PersistenceStorage!

        init() {
        }
    }
}
