//
//  ZeroLoggerTests.swift
//  ZeroLoggerTests
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import XCTest
import CocoaLumberjackSwift

@testable import ZeroLogger

class ZeroLoggerTests: XCTestCase {
    private var logger: ZeroLogger?
    
    override func setUp() {
        super.setUp()
        DDLog.removeAllLoggers()
        
        try! ZeroLogger.reset()
        
        logger = ZeroLogger()
        
        DDLog.add(logger)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLog() {
        let exp = expectation(description: "A log should be present in the log database.")
        waitForExpectations(timeout: 5.0, handler: nil)
        
        DDLogInfo("hello")

        logger?.dbQueue?.inDatabase({ db in
            let request = LogRecord.all()
            let count = try! request.fetchCount(db)
            XCTAssert(count == 1, "1 log entry should be present, got \(count) instead.")
            exp.fulfill()
        })
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
