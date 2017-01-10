//
//  RelayTests.swift
//  RelayTests
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import XCTest
import CocoaLumberjackSwift
import GRDB

@testable import Relay

class RelayTests: XCTestCase, RelayDelegate {
    private var logger: Relay?
    private var successBlock: ((_ record: LogRecord) -> Void)?
    private var failureBlock: ((_ record: LogRecord, _ error: Error?,_ response: HTTPURLResponse?) -> Void)?

    override class func setUp() {
        RelayTests.deleteRelayDirectory()
    }

    override func setUp() {
        super.setUp()
        
        DDLog.removeAllLoggers()
        DDLog.add(logger)

        successBlock = nil
        failureBlock = nil
    }

    // Esure a log message is correctly inserted in the logger database
    func testLogger() {
        
        logger = try! Relay(identifier:"testLogger")
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
        
        logger = try! Relay(identifier:"testSuccessfulLogFlush")
        sessionMock.delegate = logger
        setupLogger(logger: logger, configuration: config, session: sessionMock)
        
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
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "loggerTest", code: 5, userInfo: nil)
        let sessionMock = URLSessionMock(data: nil, response: response, error: error)
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)

        logger = try! Relay(identifier:"testFailedLogFlush")
        sessionMock.delegate = logger

        setupLogger(logger: logger, configuration: config, session: sessionMock)

        DDLogInfo("This should fail to upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "A bad response should have occured when uploading this log.")

        failureBlock = { [weak self] record, error, response in
            if let statusCode = response?.statusCode {
                XCTAssert(statusCode != 200)
                exp.fulfill()
                self?.failureBlock = nil
            }
        }
        try! logger?.flushLogs()
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFailedUploadRetries() {
        let exp = expectation(description: "A log past the number of upload retries should be deleted.")
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)

        let sessionMock = URLSessionMock(data: nil, response: response, error: nil)
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)
        
        logger = try! Relay(identifier:"testFailedUploadRetries")

        sessionMock.delegate = logger
        
        setupLogger(logger: logger, configuration: config, session: sessionMock)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        
        // The default number of retries is 3, so let's ensure our failureBlock is called 3 times.
        
        var failureCount = 0
        failureBlock = { record in
            failureCount += 1
            if failureCount == self.logger!.uploadRetries - 1 {
                // the database should be empty
                DispatchQueue.main.async {
                    self.logger?.dbQueue?.inDatabase({ db in
                        let request = LogRecord.all()
                        let count = try! request.fetchCount(db)
                        XCTAssert(count == 0, "No log entries should be present, got \(count) instead.")
                        exp.fulfill()
                    })
                }
            }
        }
        try! logger?.flushLogs()

        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCleanup() {
        let exp = expectation(description: "A log with a task ID no longer present in the session should be reuploaded.")
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let sessionMock = URLSessionMock(data: nil, response: response, error: nil)
        let config = RelayRemoteConfiguration(host: URL(string: "https://thisdoesntmatter.com/logs")!)
        
        logger = try! Relay(identifier:"testCleanup")
        sessionMock.delegate = logger
        
        setupLogger(logger:logger, configuration: config, session: sessionMock)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        
        // manually specify a nonexistent taskID
        let nonexistentTaskID = -12
        try! logger?.dbQueue?.inDatabase({ db in
            let record = try LogRecord.fetchOne(db)
            record?.uploadTaskID = nonexistentTaskID
            try record?.save(db)
            
        })
        try! logger?.cleanup()
        try! logger?.dbQueue?.inDatabase({ db in
            let record = try LogRecord.fetchOne(db)
            XCTAssertTrue(record?.uploadTaskID != nonexistentTaskID)
            exp.fulfill()
        })
    
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    //MARK: RelayDelegate methods
    
    func relay(relay: Relay, didUploadLogRecord record: LogRecord) {
        successBlock?(record)
    }
    
    func relay(relay: Relay, didFailToUploadLogRecord record: LogRecord, error: Error?, response: HTTPURLResponse?) {
        failureBlock?(record, error, response)
    }
    
    // MARK: Helpers
    
    private func setupLogger(logger: Relay?, configuration: RelayRemoteConfiguration? = nil, session: URLSessionProtocol? = nil) {
        DDLog.removeAllLoggers()
        DDLog.add(logger)
        logger?.delegate = self
        logger?.configuration = configuration
        logger?.urlSession = session
    }
    
    private static func deleteRelayDirectory() {
        do {
            try FileManager.default.removeItem(at: relayPath())
        } catch {
            // According to the documentation, checks to see if the operation will succeed first are discouraged.
        }
    }
}
