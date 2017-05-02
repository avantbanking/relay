//
//  LogRecord.swift
//  Relay
//
//  Created by Evan Kimia on 1/8/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation
import RealmSwift
import CocoaLumberjackSwift


public class LogRecord : Object {
    
    public var uuid: String {
        guard let _uuid = _uuid else { fatalError() }
        
        return _uuid
    }
    
    public var message: String {
        guard let _message = _message else { fatalError() }
        
        return _message
    }

    public var flag: Int {
        guard let _flag = _flag.value else { fatalError() }
        
        return _flag
    }
    
    public var level: Int {
        guard let _level = _level.value else { fatalError() }
        
        return _level
    }
    
    public var line: Int {
        guard let _line = _line.value else { fatalError() }
        
        return _line
    }
    
    public var file: String {
        guard let _file = _file else { fatalError() }
        
        return _file
    }
    
    public var context: Int {
        guard let _context = _context.value else { fatalError() }
        
        return _context
    }
    
    public var function: String {
        guard let _function = _function else { fatalError() }
        
        return _function
    }
    
    public var date: Date {
        guard let _date = _date else { fatalError() }
        
        return _date
    }
    
    public var uploadTaskID: Int? {
        get {
            return _uploadTaskID.value
        }
        set {
            _uploadTaskID.value = newValue
        }
    }
    
    public dynamic var uploadRetries = 0

    private dynamic var _uuid: String?
    
    private dynamic var _message: String?

    private let _flag = RealmOptional<Int>()

    private let _level = RealmOptional<Int>()

    private let _line = RealmOptional<Int>()

    private dynamic var _file: String?

    private let _context = RealmOptional<Int>()

    private dynamic var _function: String?

    private dynamic var _date: Date?
    
    private let _uploadTaskID = RealmOptional<Int>()

    

//    required public init(row: Row) {
//        uuid = row.value(named: "uuid")
//        message = row.value(named: "message")
//        flag = row.value(named: "flag")
//        level = row.value(named: "level")
//        line = row.value(named: "line")
//        file = row.value(named: "file")
//        context = row.value(named: "context")
//        function = row.value(named: "function")
//        date = row.value(named: "date")
//        uploadTaskID = row.value(named: "upload_task_id")
//        
//        super.init(row: row)
//        uploadRetries = row.value(named: "upload_retries")
//    }
    
    convenience init(logMessage: DDLogMessage, loggerIdentifier: String) {
        self.init()

        _uuid = UUID().uuidString
        _message = logMessage.message
        _flag.value = Int(logMessage.flag.rawValue)
        _level.value = Int(logMessage.level.rawValue)
        _line.value = Int(logMessage.line)
        _file = logMessage.file
        _context.value = logMessage.context
        _function = logMessage.function
        _date = logMessage.timestamp
        
    }
    
    
    var dict: [String: Any] {
        var dict: [String: Any] = [:]
        dict["uuid"] = uuid
        dict["message"] = message
        dict["flag"] = flag
        dict["level"] = level
        dict["date"] = date.description
        
        return dict
    }
    
    var logMessage: DDLogMessage {
        return DDLogMessage(message: message,
                                      level: DDLogLevel(rawValue: UInt(level))!,
                                      flag: DDLogFlag(rawValue: UInt(flag)),
                                      context: context,
                                      file: file,
                                      function: function,
                                      line: UInt(line),
                                      tag: nil,
                                      options: DDLogMessageOptions(rawValue:0), // Only value CocoaLumberjack uses.
                                      timestamp: date)
    }
    
}
