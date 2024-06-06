//
//  TestNewDI.swift
//  MindboxTests
//
//  Created by Sergei Semko on 6/5/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

fileprivate protocol TestDIProtocol: AnyObject {
    func someFunc() -> String
}

fileprivate class TestDI: TestDIProtocol {}
fileprivate class MockDI: TestDIProtocol {}

fileprivate extension Container {
    func registerTestDITests() -> Self {
        register(TestDIProtocol.self) {
            TestDI()
        }
        
        return self
    }
    
    func registerTestDIMocks() -> Self {
        register(TestDIProtocol.self) {
            MockDI()
        }
        
        return self
    }
}

final class TestNewDI: XCTestCase {

    var container: Container!
    
    override func setUp() {
        super.setUp()
        container = Container()
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    func testReturnSameInstanceOfServiceWhenRegisterAndResolveService() {
        container.register(TestDIProtocol.self) {
            TestDI()
        }
        
        let firstObject: TestDIProtocol? = container.resolve(TestDIProtocol.self)
        let secondObject: TestDIProtocol? = container.resolve(TestDIProtocol.self)
        
        XCTAssertNotNil(firstObject)
        XCTAssertNotNil(secondObject)
        XCTAssertIdentical(firstObject, secondObject, "The same instance is expected")
    }
    
    func testReturnNilWhenServiceIsMissing() {
        let someObject: TestDIProtocol? = container.resolve(TestDIProtocol.self)
        XCTAssertNil(someObject)
    }

    func testResolveServiceWhenInjectionModeIsStandart() {
        MBInject.mode = .standard
        let container = MBInject.depContainer
        container.register(TestDIProtocol.self) {
            TestDI()
        }
        
        let someObject: TestDIProtocol? = container.inject(TestDIProtocol.self)
        
        XCTAssertNotNil(someObject)
        XCTAssertTrue(someObject is TestDI)
        XCTAssertFalse(someObject is MockDI)
    }
    
    func testResolveTestsServiceWhenInjectionModeIsTest() {
        MBInject.mode = .test({ container in
            container.registerTestDIMocks()
        })
        let container = MBInject.depContainer
        
        let someObject: TestDIProtocol? = container.inject(TestDIProtocol.self)
        
        XCTAssertNotNil(someObject)
        XCTAssertTrue(someObject is MockDI)
        XCTAssertFalse(someObject is TestDI)
    }
    
    func testInjectServiceWhenRegisterStandartContainers() {
        let someObject: TestDIProtocol = container
            .registerTestDITests()
            .inject(TestDIProtocol.self)
        
        XCTAssertTrue(someObject is TestDI)
        XCTAssertFalse(someObject is MockDI)
    }
    
    func testInjectServiceWhenRegisterStandartAndTestContainers() {
        let someObject: TestDIProtocol = container
            .registerTestDITests()
            .registerTestDIMocks()
            .inject(TestDIProtocol.self)
        
        XCTAssertTrue(someObject is MockDI)
        XCTAssertFalse(someObject is TestDI)
    }
    
    func testContainerTest() {
        let someObject: PersistenceStorage? = testContainer.inject(PersistenceStorage.self)
        XCTAssertTrue(someObject is MockPersistenceStorage)
        XCTAssertFalse(someObject is MBPersistenceStorage)
    }
}


fileprivate extension TestDIProtocol {
    func someFunc() -> String {
        String(describing: self)
    }
}

fileprivate enum TestDIObjectsDescriptions: String {
    case testDI = "MindboxTests.TestDI"
    case mockDI = "MindboxTests.MockDI"
    case stubDI = "MindboxTests.StubDI"
}
