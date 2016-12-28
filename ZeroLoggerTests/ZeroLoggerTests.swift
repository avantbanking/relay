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
    }
    
    override func tearDown() {
        super.tearDown()
        try! logger?.reset()
    }

    /// Esure a log message is correctly inserted in the logger database
    func testLogger() {
        logger = try! ZeroLogger(dbPath: nil)
        setupLogger(logger: logger)

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
        let responseString = "{\"login\": \"dasdom\", \"id\": 1234567}"
        let responseData = responseString.data(using: String.Encoding.utf8)!
        let sessionMock = URLSessionMock(data: responseData, response: nil, error: nil)
        
        logger = try! ZeroLogger(dbPath: nil, session: sessionMock)
        logger?.logUploadEndpoint = URL(string: "https://thisdoesntmatter.com/logs")!
        setupLogger(logger: logger)
        
        DDLogInfo("This should successfully upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "No network errors should occur when flushing logs.")
        try! logger?.flushLogs(callback: { record, error in
            if error == nil {
                exp.fulfill()
            }
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    private func setupLogger(logger: ZeroLogger?) {
        DDLog.removeAllLoggers()
        DDLog.add(logger)
    }
}
