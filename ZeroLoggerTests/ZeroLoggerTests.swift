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
        
        do {
            logger = try ZeroLogger(dbPath: nil)
        } catch _ {
            fatalError("Failed to initialize ZeroLogger!")
        }
        
        DDLog.add(logger)
    }
    
    override func tearDown() {
        super.tearDown()
    }

    /// Esure a log message is correctly inserted in the logger database
    func testLogger() {
        let exp = expectation(description: "A log should be present in the log database.")
        
        DDLogInfo("hello")
        DDLog.flushLog()

        logger?.dbQueue?.inDatabase({ db in
            let request = LogRecord.all()
            let count = try! request.fetchCount(db)
            XCTAssert(count == 1, "1 log entry should be present, got \(count) instead.")
            exp.fulfill()
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSuccessfulLogFlush() {
        DDLogInfo("This should successfully upload")
        DDLogWarn("This should as well")
        DDLog.flushLog()
        
        try! logger?.flushLogs()
        
        // ...

    }
}
