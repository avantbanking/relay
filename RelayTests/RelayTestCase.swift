//
//  TestUtilities.swift
//  Relay
//
//  Created by Evan Kimia on 1/25/17.
//  Copyright © 2017 zero. All rights reserved.
//

import XCTest
import Foundation
import CocoaLumberjackSwift

@testable import Relay

class RelayTestCase: XCTestCase, RelayTestingDelegate {
    
    var relay: Relay?
    var successBlock: ((_ record: LogRecord) -> Void)?
    var recordDeletionBlock: ((_ record: LogRecord) -> Void)?
    var failureBlock: ((_ record: LogRecord, _ error: Error?,_ response: HTTPURLResponse?) -> Void)?
    

    override class func setUp() {
        RelayTestCase.deleteRelayDirectory()
    }

    
    override func setUp() {
        super.setUp()
        
        DDLog.removeAllLoggers()
        DDLog.add(relay)
        
        successBlock = nil
        failureBlock = nil
    }

    
    static func deleteRelayDirectory() {
        do {
            try FileManager.default.removeItem(at: relayPath())
        } catch {
            // According to the documentation, checks to see if the operation will succeed first are discouraged.
        }
    }
    

    func setupLogger() {
        DDLog.removeAllLoggers()
        DDLog.add(relay)
        relay?.delegate = self
    }
    

    //MARK: RelayTestingDelegate methods
    
    public func relay(relay: Relay, didUploadLogMessage message: DDLogMessage) {
        // unused.
    }
    

    func relay(relay: Relay, didUploadLogRecord record: LogRecord) {
        successBlock?(record)
    }

    
    func relay(relay: Relay, didDeleteLogRecord record: LogRecord) {
        recordDeletionBlock?(record)
    }
    
    
    func relay(relay: Relay, didFailToUploadLogRecord record: LogRecord, error: Error?, response: HTTPURLResponse?) {
        failureBlock?(record, error, response)
    }

    
    func relay(relay: Relay, didFailToUploadLogMessage message: DDLogMessage, error: Error?, response: HTTPURLResponse?) {
        // unused.
    }
}
