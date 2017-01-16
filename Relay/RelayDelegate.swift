//
//  RelayDelegate.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation

public protocol RelayDelegate: NSObjectProtocol {
    func relay(relay: Relay, didUploadLogRecord record: LogRecord)
    
    func relay(relay: Relay, didFailToUploadLogRecord record: LogRecord, error: Error?, response: HTTPURLResponse?)
}


/// Protocol used for testing.
protocol RelayTestingDelegate: RelayDelegate {
    func relay(relay: Relay, didDeleteLogRecord record: LogRecord)
}
