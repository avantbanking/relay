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
    var line: Int
    var file: String
    var context: Int
    var function: String
    var date: Date
    var uploadTaskID: Int?
    var loggerIdentifier: String
    var uploadRetries = 0
    
    required public init(row: Row) {
        uuid = row.value(named: "uuid")
        message = row.value(named: "message")
        flag = row.value(named: "flag")
        level = row.value(named: "level")
        line = row.value(named: "line")
        file = row.value(named: "file")
        context = row.value(named: "context")
        function = row.value(named: "function")
        date = row.value(named: "date")
        uploadTaskID = row.value(named: "upload_task_id")
        loggerIdentifier = row.value(named: "logger_identifier")
        
        super.init(row: row)
        uploadRetries = row.value(named: "upload_retries")
    }
    
    init(logMessage: DDLogMessage, loggerIdentifier: String) {
        uuid = UUID().uuidString
        message = logMessage.message
        flag = Int(logMessage.flag.rawValue)
        level = Int(logMessage.level.rawValue)
        line = Int(logMessage.line)
        file = logMessage.file
        context = logMessage.context
        function = logMessage.function
        date = logMessage.timestamp
        self.loggerIdentifier = loggerIdentifier
        
        super.init()
    }
    
    override public var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["uuid": uuid,
                "message": message,
                "flag": flag,
                "level": level,
                "line": line,
                "file": file,
                "context": context,
                "function": function,
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
        
        return dict
    }
}
