//
//  RelayConfigurationTests.swift
//  Relay
//
//  Created by Evan Kimia on 1/25/17.
//  Copyright © 2017 zero. All rights reserved.
//

import XCTest
import CocoaLumberjackSwift

@testable import Relay

class RelayConfigurationTests: RelayTestCase {

    func testHeaderUpdate() {
        let exp = expectation(description: "Should remake requests when the configuration changes.")
        
        let host = URL(string: "http://testHeaderUpdate.com")!
        let config = RelayConfiguration(host: host, additionalHttpHeaders: ["Hello": "You."])
        createTestLogs(withRelayIdentifier: "testRemoteConfigurationUpdate", config: config)
        
        let newConfigHeaders = ["Goodbye": "See you later."]
        let newConfig = RelayConfiguration(host: host, additionalHttpHeaders: newConfigHeaders)
        relay?.configuration = newConfig
        
        relay?.dbQueue?.inDatabase({ _ in
            // Grab the network task and verify it has the information from configTwo
            relay?.urlSession?.getAllTasks(completionHandler: { tasks in
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
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    
    func testHostChange() {
        let exp = expectation(description: "Should remake requests when the host changes.")

        let config = RelayConfiguration(host: URL(string: "http://host.com")!)
        createTestLogs(withRelayIdentifier: "testHeaderHostChange", config: config)
        
        let newConfig = RelayConfiguration(host: URL(string: "http://newhost.com")!)
        relay?.configuration = newConfig

        relay?.dbQueue?.inDatabase({ db in
            // Grab the network task and verify it has the information from configFour
            relay?.urlSession?.getAllTasks(completionHandler: { tasks in
                guard let record = try! LogRecord.fetchOne(db),
                    let task = tasks.filter({ $0.taskIdentifier == record.uploadTaskID }).first,
                    let currentRequest = task.currentRequest,
                    let host = currentRequest.url else {
                        XCTFail("Missing required objects!")
                        return
                }
                XCTAssertEqual(host, newConfig.host)
                exp.fulfill()
            })
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    
    private func createTestLogs(withRelayIdentifier identifier: String, config: RelayConfiguration) {
        let sessionMock = URLSessionMock()
        sessionMock.taskResponseTime = 10 // Make it long enough so the network task is still present when we switch configs
        
        relay = Relay(identifier:identifier,
                      configuration: config,
                      testSession:sessionMock)
        
        sessionMock.delegate = relay
        
        setupLogger()
        
        DDLogInfo("Testing one two...")
        DDLog.flushLog()
    }
}
