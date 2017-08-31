//
//  RelayRemoteConfigurationTests.swift
//  Relay
//
//  Created by Evan Kimia on 1/25/17.
//  Copyright © 2017 zero. All rights reserved.
//

import XCTest
import CocoaLumberjackSwift

@testable import Relay


class RelayRemoteConfigurationTests: RelayTestCase {
    
    func testHeaderUpdate() {
        let exp = expectation(description: "Should remake requests when the configuration changes.")
        
        let sessionMock = URLSessionMock()
        sessionMock.taskResponseTime = 10 // Make it long enough so the network task is still present when we switch configs

        let host = URL(string: "http://testHeaderUpdate.com")!
        let config = RelayRemoteConfiguration(host: host, httpHeaders: ["Hello": "You."])
        let relay = createTestLogs(withRelayIdentifier: "testRemoteConfigurationUpdate", config: config, sessionMock: sessionMock)
        
        let newConfigHeaders = ["Goodbye": "See you later."]
        let newConfig = RelayRemoteConfiguration(host: host, httpHeaders: newConfigHeaders)
        relay.configuration = newConfig
        relay.completionQueue.waitUntilAllOperationsAreFinished()
        
        // Grab the network task and verify it has the information from configTwo
        relay.urlSession?.getAllTasks(completionHandler: { tasks in
            guard let task = tasks.last,
                let currentRequest = task.currentRequest,
                let requestHeaders = currentRequest.allHTTPHeaderFields,
                let configTwoKey = newConfigHeaders.keys.first else {
                    XCTFail("Missing required objects!")
                    return
            }
            XCTAssertEqual(requestHeaders[configTwoKey], newConfigHeaders[configTwoKey])
            exp.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    
    func testHostChange() {
        let exp = expectation(description: "Should remake requests when the host changes.")
        
        let sessionMock = URLSessionMock()
        sessionMock.taskResponseTime = 10 // Make it long enough so the network task is still present when we switch configs
    
        let config = RelayRemoteConfiguration(host: URL(string: "http://host.com")!)
        let relay = createTestLogs(withRelayIdentifier: "testHeaderHostChange", config: config, sessionMock: sessionMock)
        
        let newConfig = RelayRemoteConfiguration(host: URL(string: "http://newhost.com")!)
        relay.configuration = newConfig
        relay.completionQueue.waitUntilAllOperationsAreFinished()
        
        // Grab the network task and verify it has the information from newConfig
        relay.urlSession?.getAllTasks(completionHandler: { tasks in
            guard let record = relay.realm.objects(LogRecord.self).first,
                let task = tasks.filter({ $0.taskIdentifier == record.uploadTaskID }).first,
                let currentRequest = task.currentRequest,
                let host = currentRequest.url else {
                    XCTFail("Missing required objects!")
                    return
            }
            XCTAssertEqual(host, newConfig.host)
            exp.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    
    func testSuccessfulStatusCodeChange() {
        let exp = expectation(description: "Should remake requests when the successful status codes change.")
        
        let host = URL(string: "http://host.com")!
        let response = HTTPURLResponse(url: host, statusCode: 202, httpVersion: nil, headerFields: nil)
        let error = NSError(domain: "loggerTest", code: 5, userInfo: nil)
        let sessionMock = URLSessionMock(data: nil, response: response, error: error)
        
        _ = createTestLogs(withRelayIdentifier: "testSuccessfulStatusCodeChange",
                           config: RelayRemoteConfiguration(host: host, successfulHTTPStatusCodes: [202]),
                           sessionMock: sessionMock)

        successBlock = { _ in
            exp.fulfill()
        }
        failureBlock = { _ in
            XCTFail("Expected a successful upload, got a failure instead.")
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    

    // MARK: Helpers

    private func createTestLogs(withRelayIdentifier identifier: String, config: RelayRemoteConfiguration, sessionMock: URLSessionMock? = nil) -> Relay {
        
        let relay = Relay(identifier:identifier,
                          configuration: config,
                          testSession:sessionMock)
        
        sessionMock?.delegate = relay
        setupRelay(relay)
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
        relay.completionQueue.waitUntilAllOperationsAreFinished()

        return relay
    }
}
