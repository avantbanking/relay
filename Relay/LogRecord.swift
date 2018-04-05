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


public class LogRecord: Object {
    
    var uuid: String {
        guard let _uuid = _uuid else { fatalError() }
        
        return _uuid
    }
    
    var message: String {
        guard let _message = _message else { fatalError() }
        
        return _message
    }

    var flag: Int {
        guard let _flag = _flag.value else { fatalError() }
        
        return _flag
    }
    
    var level: Int {
        guard let _level = _level.value else { fatalError() }
        
        return _level
    }
    
    var line: Int {
        guard let _line = _line.value else { fatalError() }
        
        return _line
    }
    
    var file: String {
        guard let _file = _file else { fatalError() }
        
        return _file
    }
    
    var context: Int {
        guard let _context = _context.value else { fatalError() }
        
        return _context
    }
    
    var function: String {
        guard let _function = _function else { fatalError() }
        
        return _function
    }
    
    var date: Date {
        guard let _date = _date else { fatalError() }
        
        return _date
    }
    
    var uploadTaskID: Int? {
        get {
            return _uploadTaskID.value
        }
        set {
            _uploadTaskID.value = newValue
        }
    }
    
    @objc dynamic var uploadRetries = 0

    @objc private dynamic var _uuid: String?
    
    @objc private dynamic var _message: String?

    private let _flag = RealmOptional<Int>()

    private let _level = RealmOptional<Int>()

    private let _line = RealmOptional<Int>()

    @objc private dynamic var _file: String?

    private let _context = RealmOptional<Int>()

    @objc private dynamic var _function: String?

    @objc private dynamic var _date: Date?
    
    private let _uploadTaskID = RealmOptional<Int>()


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
