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
    var uploadStatus: Int

    required init(row: Row) {
        uuid = row.value(named: "uuid")
        message = row.value(named: "message")
        flag = row.value(named: "flag")
        level = row.value(named: "level")
        date = row.value(named: "date")
        uploadStatus = row.value(named: "uploadStatus")

        super.init(row: row)
    }
    
    init(logMessage: DDLogMessage) {
        uuid = UUID().uuidString
        message = logMessage.message
        flag = Int(logMessage.flag.rawValue)
        level = Int(logMessage.level.rawValue)
        date = logMessage.timestamp
        uploadStatus = 0
        
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
    
    override class var databaseTableName: String {
        return "log_messages"
    }
}


public class ZeroLogger: DDAbstractLogger {
    var dbQueue: DatabaseQueue?
    var urlSession: URLSession?
    var logUploadEndpoint: URL?

    
    private static let dbPath: String = {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else {
            return ""
        }

       return documentsPath + "/loggerdb.sqlite"
    }()
    

    /// Initializes the logger using GRDB to interface with SQLite, and your standard URLSession for uploading
    /// logs to the specified server.
    ///
    /// - Parameters:
    ///   - dbPath: Location for storing the database containing logs. Please be careful not to specify a nonpersistent
    ///   location for production use.
    ///
    ///   - logUploadEndpoint: URL to upload logs. See the `persistentDictionary` method on `LogRecord` for information
    ///   on the payload structure.
    ///
    /// - Throws: A DatabaseError is thrown whenever an SQLite error occurs. See the GRDB documentation here
    ///   for more information: https://github.com/groue/GRDB.swift#documentation
    ///
    required public init(dbPath: String? = ZeroLogger.dbPath, logUploadEndpoint: URL? = nil) throws {
        dbQueue = try DatabaseQueue(path: ZeroLogger.dbPath)
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("Documents Directory: " + documentsPath)
        }
        
        // Setup a background NSURLSessiuon
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "zerofinancial.inc.logger")
        urlSession = URLSession(configuration: backgroundConfig)
    
        try dbQueue?.inDatabase { db in
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
                t.column("upload_status", .integer).notNull().defaults(to: 0)
            }
        }
    }
    
    override init() {
        fatalError("Please use init(dbPath:) instead.")
    }
    
    static func reset() throws {
        if FileManager.default.fileExists(atPath: ZeroLogger.dbPath) {
            try FileManager.default.removeItem(atPath: ZeroLogger.dbPath)
        }
    }
    
    func uploadLogs() throws {
        let logUploadRequest = URLRequest(url: URL(string: "sdffdsffds")!)
        try dbQueue?.inDatabase({ db in
            let logRecords = try LogRecord.filter(Column("upload_status") == 0).fetchAll(db)
            for record in logRecords {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: record.persistentDictionary, options: .prettyPrinted)
                    let task = urlSession?.uploadTask(with: logUploadRequest, from: jsonData)
                    task?.resume()
                    
                    record.uploadStatus = 1
                    try record.save(db)
                } catch {
                    print(error.localizedDescription)
                }
            }
        })
    }
    
    // MARK: DDAbstractLogger Methods

    override public func log(message logMessage: DDLogMessage!) {
        // Generate a LogRecord from a LogMessage
        let logRecord = LogRecord(logMessage: logMessage)
        try! dbQueue?.inDatabase({ db in
            try logRecord.insert(db)
        })
    }
}
