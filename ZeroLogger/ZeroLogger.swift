//
//  ZeroLogger.swift
//  ZeroLogger
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjack

fileprivate struct LogMessage {
    let uuid: String
    var context: String?
    
    init(logMessage: DDLogMessage) {
        uuid = ""
    }
}

public class ZeroLogger: DDAbstractLogger {
    var dbQueue: DatabaseQueue?
    
    override init() {
        do {
            dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
        } catch _ {
            //
        }

    }
    
    override public func log(message logMessage: DDLogMessage!) {
        
    }

}
