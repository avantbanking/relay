//
//  RelayDelegate.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation
import CocoaLumberjack


public protocol RelayDelegate: NSObjectProtocol {
    

    /// Returns the `LogMessage` that has been successfully uploaded.
    ///
    /// - Parameters:
    ///   - relay
    ///   - message
    func relay(relay: Relay, didUploadLogMessage message: DDLogMessage)
    
    /// Returns the `LogMessage` that failed to upload after `uploadRetries` attempts.
    ///
    /// - Parameters:
    ///   - relay
    ///   - message
    ///   - error
    ///   - response
    func relay(relay: Relay, didFailToUploadLogMessage message: DDLogMessage, error: Error?, response: HTTPURLResponse?)
}
