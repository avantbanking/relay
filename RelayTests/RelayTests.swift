//
//  RelayTests.swift
//  RelayTests
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import XCTest
import CocoaLumberjackSwift


@testable import Relay

class RelayTests: XCTestCase, RelayDelegate {
    private var logger: Relay?
    private var successBlock: ((_ record: LogRecord) -> Void)?
    private var failureBlock: ((_ record: LogRecord) -> Void)?
    
    override func setUp() {
        super.setUp()

        let documentsDiretory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let dbPath = documentsDiretory + "/loggerdb.sqlite"
        if FileManager.default.fileExists(atPath: dbPath) {
            try! FileManager.default.removeItem(atPath: dbPath)
        }
        successBlock = nil
        failureBlock = nil
    }
    
    override func tearDown() {
        super.tearDown()
    }

    /// Esure a log message is correctly inserted in the logger database
    func testLogger() {
        logger = try! Relay(identifier:"loggerTests")

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
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)
        
        logger = try! Relay(identifier:"loggerTests", configuration: config, session: sessionMock)
        sessionMock.delegate = logger
        
        setupLogger(logger: logger)
        
        DDLogInfo("This should successfully upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "No network errors should occur when flushing logs.")
        
        successBlock = { record in
            exp.fulfill()
        }
        
        try! logger?.flushLogs()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFailedLogFlush() {
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "loggerTest", code: 5, userInfo: nil)
        let sessionMock = URLSessionMock(data: nil, response: response, error: error)
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)

        logger = try! Relay(identifier:"loggerTests", configuration: config, session: sessionMock)
        sessionMock.delegate = logger
        
        setupLogger(logger: logger)
        
        DDLogInfo("This should fail to upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "An error should have occured when uploading this log.")

        failureBlock = { record in
            XCTAssertNotNil(error)
            exp.fulfill()
        }
        try! logger?.flushLogs()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFailedUploadRetries() {
        let exp = expectation(description: "A log past the number of upload retries should be deleted.")
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)

        let sessionMock = URLSessionMock(data: nil, response: response, error: nil)
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)
        
        logger = try! Relay(identifier:"loggerTests", configuration: config, session: sessionMock)
        sessionMock.delegate = logger
        
        setupLogger(logger: logger)
        
        DDLogInfo("Testing one two...")
        
        // The default number of retries is 3, so let's ensure our failureBlock is called 3 times.
        DDLog.flushLog()
        
        failureBlock = { record in
            print("hello \(record.uuid)")
        }
        try! logger?.flushLogs()
        
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    //MARK: RelayDelegate methods
    
    func relay(relay: Relay, didUploadLogRecord record: LogRecord) {
        successBlock?(record)
    }
    
    func relay(relay: Relay, didFailToUploadLogRecord record: LogRecord, error: Error?, response: HTTPURLResponse?) {
        failureBlock?(record)
    }
    
    // MARK: Helpers
    
    private func setupLogger(logger: Relay?) {
        DDLog.removeAllLoggers()
        DDLog.add(logger)
        logger?.delegate = self
    }
}
