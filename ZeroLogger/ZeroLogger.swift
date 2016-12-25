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


class LogRecord : Record {
    var uuid: String
    var message: String
    var flag: Int
    var level: Int
    var date: Date

    override class var databaseTableName: String {
        return "log_messages"
    }

    required init(row: Row) {
        uuid = row.value(named: "uuid")
        message = row.value(named: "message")
        flag = row.value(named: "flag")
        level = row.value(named: "level")
        date = row.value(named: "date")

        super.init(row: row)
    }
    
    init(logMessage: DDLogMessage) {
        uuid = UUID().uuidString
        message = logMessage.message
        flag = Int(logMessage.flag.rawValue)
        level = Int(logMessage.level.rawValue)
        date = logMessage.timestamp
        
        super.init()
    }
    
    
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["uuid": uuid,
                "message": message,
                "flag": flag,
                "level": level,
                "date": date
        ]
    }
}


public class ZeroLogger: DDAbstractLogger {
    var dbQueue: DatabaseQueue?
    private static let dbPath = "loggerdb.sqlite"
    
    static func reset() throws {
        if FileManager.default.fileExists(atPath: ZeroLogger.dbPath) {
            try FileManager.default.removeItem(atPath: ZeroLogger.dbPath)
        }
    }
    
    override init() {
            dbQueue = try! DatabaseQueue(path: ZeroLogger.dbPath)
            try! dbQueue?.inDatabase { db in
                try db.create(table: "log_messages") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("uuid", .text)
                    t.column("message", .text)
                    t.column("flag", .integer).notNull()
                    t.column("level", .integer).notNull()
                    t.column("context", .text)
                    t.column("file", .text)
                    t.column("function", .text)
                    t.column("line", .integer)
                    t.column("date", .datetime)
                }
            }
    }
    
    override public func log(message logMessage: DDLogMessage!) {
        // Generate a LogRecord from a LogMessage
        let logRecord = LogRecord(logMessage: logMessage)
        try! dbQueue?.inDatabase({ db in
            try logRecord.insert(db)
        })
    }
}
