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
        let relay = Relay(identifier:"testLogger",
                          configuration: RelayConfiguration(host: URL(string: "http://doesntmatter.com")!))
        self.relay = relay
        setupLogger()
        
        let exp = expectation(description: "A log should be present in the log database.")

        DDLogInfo("hello")
        DDLog.flushLog()
        
        relay.write() { realm in
            let count = relay.realm.objects(LogRecord.self).count
            XCTAssert(count == 1, "1 log entry should be present, got \(count) instead.")
            exp.fulfill()
        }

        
        waitForExpectations(timeout: 5, handler: nil)
    }
    

    func testDiskQuota() {
        let relay = createRelay(withIdentifier: "testDiskQuota",
                    configuration: RelayConfiguration(host: URL(string: "http://example.com")!))

        relay.maxNumberOfLogs = 10
        
        let exp = expectation(description: "The database should have at most the value of the `maxNumberOfLogs` property.")
        
        for _ in 0...relay.maxNumberOfLogs + 1 {
            DDLogInfo("abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789")
        }
        DDLog.flushLog()
        
        relay.write() { realm in
            let count = relay.realm.objects(LogRecord.self).count
            XCTAssert(count == relay.maxNumberOfLogs, "\(relay.maxNumberOfLogs) log entries should be present, got \(count) instead.")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testSuccessfulLogFlush() {
        let sessionMock = URLSessionMock(response: HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil))

        let relay = createRelay(withIdentifier: "testSuccessfulLogFlush",
                    configuration: RelayConfiguration(host: URL(string: "http://example.com")!),
                    sessionMock: sessionMock)
        
        DDLogInfo("This should successfully upload")
        DDLog.flushLog()
        
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
        
        let relay = createRelay(withIdentifier: "testFailedLogFlush",
                    configuration: RelayConfiguration(host: URL(string: "http://example.com")!),
                    sessionMock: sessionMock)
        
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
            relay.write() { realm in
                let count = relay.realm.objects(LogRecord.self).count
                XCTAssert(count == 0, "No log entries should be present, got \(count) instead.")
                exp.fulfill()
            }
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
        sessionMock.taskResponseTime = 10 // Make it long enough so the network task is still present when we switch configs
        
        let configOne = RelayConfiguration(host: URL(string: "http://doesntmatter.com")!, additionalHttpHeaders: ["Hello": "You."])
        
        let relay = createRelay(withIdentifier: "testReset", configuration: configOne, sessionMock: sessionMock)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        relay.reset()
        
        relay.write() { realm in
            // Grab the network task and verify it has the information from configTwo
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
        
        let relay = createRelay(withIdentifier: "testCleanup", configuration: RelayConfiguration(host: URL(string: "http://example.com")!), sessionMock: sessionMock)

        setupLogger()
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        
        // manually specify a nonexistent taskID
        let nonexistentTaskID = -12
        relay.write() { realm in
            let record = realm.objects(LogRecord.self).first
            record?.uploadTaskID = nonexistentTaskID
        }
        
        relay.cleanup()
        relay.write() { realm in
            let record = realm.objects(LogRecord.self).first
            XCTAssertTrue(record?.uploadTaskID != nonexistentTaskID)
            exp.fulfill()
        }

        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testHandleRelayUrlSessionEvents() {
        let relay = Relay(identifier:"testHandleRelayUrlSessionEvents",
                      configuration: RelayConfiguration(host: URL(string: "http://doesntmatter.com")!))
        
        XCTAssertNil(relay.sessionCompletionHandler)
        
        relay.handleRelayUrlSessionEvents(identifier: relay.identifier,
                                           completionHandler: { })
        XCTAssertTrue(relay.sessionCompletionHandler != nil)
    }


    // MARK: Helpers

    private func createRelay(withIdentifier identifier: String, configuration: RelayConfiguration, sessionMock: URLSessionMock? = nil) -> Relay {
        let relay = Relay(identifier:identifier,
                      configuration: configuration,
                      testSession:sessionMock)
        self.relay = relay
        
        sessionMock?.delegate = relay
        setupLogger()

        return relay
    }
}
