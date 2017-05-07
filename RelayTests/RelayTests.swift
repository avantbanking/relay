//
//  RelayTests.swift
//  RelayTests
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import XCTest
import CocoaLumberjack
import CocoaLumberjackSwift
import Realm
import RealmSwift

@testable import Relay


class RelayTests: RelayTestCase {
    
    // Ensures a log message is correctly inserted in the logger database
    func testLogger() {
        let relay = createRelay(withIdentifier: "testLogger")
        
        DDLogInfo("hello")
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()
        
        let count = relay.realm.objects(LogRecord.self).count
        XCTAssert(count == 1, "1 log entry should be present, got \(count) instead.")
    }
    
    // "The database should have at most the value of the `maxNumberOfLogs` property."
    func testDiskQuota() {
        let sessionMock = URLSessionMock(response: HTTPURLResponse(url: URL(string: "http://example.com")!,
                                                                   statusCode: 200, httpVersion: nil, headerFields: nil))
        sessionMock.taskResponseTime = 2 // don't have the logs immediately upload

        let relay = createRelay(withIdentifier: "testDiskQuota", sessionMock: sessionMock)
        relay.maxNumberOfLogs = 10

        for _ in 0...relay.maxNumberOfLogs + 1 {
            DDLogInfo("abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789")
        }
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()

        let count = relay.realm.objects(LogRecord.self).count
        XCTAssert(count == relay.maxNumberOfLogs, "\(relay.maxNumberOfLogs) log entries should be present, got \(count) instead.")
    }
    
    // No network errors should occur when flushing logs.
    func testSuccessfulLogFlush() {
        let sessionMock = URLSessionMock(response: HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil))

        let relay = createRelay(withIdentifier: "testSuccessfulLogFlush",
                    configuration: RelayConfiguration(host: URL(string: "http://example.com")!),
                    sessionMock: sessionMock)
        
        DDLogInfo("This should successfully upload")
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()
        
        let exp = expectation(description: "No network errors should occur when flushing logs.")
        
        successBlock = { record in
            exp.fulfill()
        }
        
        relay.flushLogs()
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testFailedLogFlush() {
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "loggerTest", code: 5, userInfo: nil)
        let sessionMock = URLSessionMock(data: nil, response: response, error: error)
        
        let relay = createRelay(withIdentifier: "testFailedLogFlush", sessionMock: sessionMock)
        
        DDLogInfo("This should fail to upload")
        DDLog.flushLog()
        
        let exp = expectation(description: "")
        
        failureBlock = { [weak self] record, error, response in
            if let statusCode = response?.statusCode {
                XCTAssert(statusCode != 200)
                exp.fulfill()
                self?.failureBlock = nil
            }
        }
        relay.flushLogs()

        waitForExpectations(timeout: 5, handler: nil)
    }

    
    func testFailedUploadRetries() {
        let exp = expectation(description: "A log past the number of upload retries should be deleted.")
        let sessionMock = URLSessionMock(response: HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 500, httpVersion: nil, headerFields: nil))

        let relay = createRelay(withIdentifier: "testFailedUploadRetries",
                    configuration: RelayConfiguration(host: URL(string: "http://example.com")!),
                    sessionMock: sessionMock)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()

        failureBlock = { record in
            // the database should be empty
            relay.write({ realm in
                let count = relay.realm.objects(LogRecord.self).count
                XCTAssert(count == 0, "No log entries should be present, got \(count) instead.")
                exp.fulfill()
            })
        }
        relay.flushLogs()
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testCancelledTask() {
        let exp = expectation(description: "A task cancelled should result in the log record being deleted.")
        
        let error = NSError(domain: "", code: NSURLErrorCancelled, userInfo: nil)
        let sessionMock = URLSessionMock(error: error)
        
        _ = createRelay(withIdentifier: "testCancelledTask", configuration: RelayConfiguration(host: URL(string: "http://example.com")!), sessionMock: sessionMock)

        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        
        recordDeletionBlock = { record in
            exp.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testReset() {
        let exp = expectation(description: "No logs should be present after a reset.")

        let sessionMock = URLSessionMock()
        sessionMock.taskResponseTime = 2 // Make it long enough so the network task is still present when we switch configs
        
        let relay = createRelay(withIdentifier: "testReset", sessionMock: sessionMock)
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()

        relay.reset() {
            relay.realm.refresh()
            let count = relay.realm.objects(LogRecord.self).count
            XCTAssert(count == 0, "No log entries should be present, got \(count) instead.")
            exp.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testCleanup() {
        let exp = expectation(description: "A log with a task ID no longer present in the session should be reuploaded.")
        let response = HTTPURLResponse(url: URL(string: "http://doesntmatter.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let sessionMock = URLSessionMock(data: nil, response: response, error: nil)
        sessionMock.taskResponseTime = 2 // We don't want the log upload immediately.
        
        let relay = createRelay(withIdentifier: "testCleanup",
                                sessionMock: sessionMock)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()
        
        // manually specify a nonexistent taskID
        let nonexistentTaskID = -12
        relay.write({ realm in
            let record = realm.objects(LogRecord.self).first
            record?.uploadTaskID = nonexistentTaskID
        })
        
        relay.cleanup() {
            relay.realm.refresh()
            let record = relay.realm.objects(LogRecord.self).first
            XCTAssertTrue(record?.uploadTaskID != nonexistentTaskID)
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testHandleRelayUrlSessionEvents() {
        let relay = createRelay(withIdentifier: "testHandleRelayUrlSessionEvents")
        
        XCTAssertNil(relay.sessionCompletionHandler)
        
        relay.handleRelayUrlSessionEvents(identifier: relay.identifier,
                                           completionHandler: { })
        XCTAssertTrue(relay.sessionCompletionHandler != nil)
    }


    // MARK: Helpers

    private func createRelay(withIdentifier identifier: String,
                             configuration: RelayConfiguration? = nil,
                             sessionMock: URLSessionMock? = nil) -> Relay {
        
        let relay = Relay(identifier:identifier,
                      configuration: configuration ?? RelayConfiguration(host: URL(string: "http://example.com")!),
                      testSession:sessionMock)
        
        sessionMock?.delegate = relay
        setupRelay(relay)

        return relay
    }
}
