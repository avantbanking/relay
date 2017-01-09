//
//  LogRecord.swift
//  Relay
//
//  Created by Evan Kimia on 1/8/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjack

public class LogRecord : Record {
    var uuid: String
    var message: String
    var flag: Int
    var level: Int
    var date: Date
    var uploadTaskID: Int?
    var uploaded = false
    var loggerIdentifier: String
    var uploadRetries: Int = 0
    
    
    required public init(row: Row) {
        uuid = row.value(named: "uuid")
        message = row.value(named: "message")
        flag = row.value(named: "flag")
        level = row.value(named: "level")
        date = row.value(named: "date")
        uploadTaskID = row.value(named: "upload_task_id")
        loggerIdentifier = row.value(named: "logger_identifier")
        uploadRetries = row.value(named: "upload_retries")
        
        super.init(row: row)
    }
    
    init(logMessage: DDLogMessage, loggerIdentifier: String, uploadRetries: Int) {
        uuid = UUID().uuidString
        message = logMessage.message
        flag = Int(logMessage.flag.rawValue)
        level = Int(logMessage.level.rawValue)
        date = logMessage.timestamp
        self.uploadRetries = uploadRetries
        self.loggerIdentifier = loggerIdentifier
        
        super.init()
    }
    
    override public var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["uuid": uuid,
                "message": message,
                "flag": flag,
                "level": level,
                "date": date,
                "upload_task_id": uploadTaskID,
                "logger_identifier": loggerIdentifier,
                "upload_retries": uploadRetries
        ]
    }
    
    override public class var databaseTableName: String {
        return "log_messages"
    }
    
    func dict() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["uuid"] = uuid
        dict["message"] = message
        dict["flag"] = flag
        dict["level"] = level
        dict["date"] = date.description
        dict["uploaded"] = uploaded
        
        return dict
    }
}
