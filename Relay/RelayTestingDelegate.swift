//
//  RelayTestingDelegate.swift
//  Relay
//
//  Created by Evan Kimia on 5/2/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


protocol RelayTestingDelegate: RelayDelegate {
    
    func relayDidFinishFlush(relay: Relay)
    
    func relay(relay: Relay, didUploadLogRecord record: LogRecord)
    
    func relay(relay: Relay, didFailToUploadLogRecord record: LogRecord, error: Error?, response: HTTPURLResponse?)
    
    func relay(relay: Relay, didDeleteLogRecord record: LogRecord)
}
