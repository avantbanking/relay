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

        let documentsDiretory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dbPath = documentsDiretory + "/loggerdb.sqlite"
        if FileManager.default.fileExists(atPath: dbPath) {
            try! FileManager.default.removeItem(atPath: dbPath)
        }
    }
    
    override func tearDown() {
        super.tearDown()
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
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let sessionMock = URLSessionMock(data: nil, response: response, error: nil)
        
        logger = try! ZeroLogger(dbPath: nil, session: sessionMock)

        logger?.logUploadEndpoint = URL(string: "https://thisdoesntmatter.com/logs")!
        setupLogger(logger: logger)
        
        DDLogInfo("This should successfully upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "No network errors should occur when flushing logs.")
        try! logger?.flushLogs(callback: { record, error, db in
            // ensure the log was uploaded.
            XCTAssertTrue(record.uploaded, "Log should have successfully been uploaded.")
            exp.fulfill()
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    private func setupLogger(logger: ZeroLogger?) {
        DDLog.removeAllLoggers()
        DDLog.add(logger)
    }
}
