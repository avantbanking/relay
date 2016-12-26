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


typealias LogFailure = (task: URLSessionUploadTask, response: HTTPURLResponse)


class LogRecord : Record {
    var uuid: String
    var message: String
    var flag: Int
    var level: Int
    var date: Date
    var uploadTaskID: Int?

    required init(row: Row) {
        uuid = row.value(named: "uuid")
        message = row.value(named: "message")
        flag = row.value(named: "flag")
        level = row.value(named: "level")
        date = row.value(named: "date")
        uploadTaskID = row.value(named: "upload_task_id")

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
    
    override class var databaseTableName: String {
        return "log_messages"
    }
}


public class ZeroLogger: DDAbstractLogger, URLSessionTaskDelegate {
    var dbQueue: DatabaseQueue?
    var urlSession: URLSession?
    var logUploadEndpoint: URL?
    
    var logFailureBlock:( (_: [LogFailure]) -> Void )?
    private static let urlSessionIdentifier = "zerofinancial.inc.logger"

    
    private static let dbPath: String = {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
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
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: ZeroLogger.urlSessionIdentifier)
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
                t.column("upload_task_id", .integer)
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
    
    func flushLogs() throws {
        guard let logUploadEndpoint = logUploadEndpoint else { return }
        try dbQueue?.inDatabase({ db in
            let logRecords = try LogRecord.filter(Column("upload_task_id") == nil).fetchAll(db)
            for record in logRecords {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: record.persistentDictionary, options: .prettyPrinted)
                    let logUploadRequest = URLRequest(url: logUploadEndpoint)
                    let task = urlSession?.uploadTask(with: logUploadRequest, from: jsonData)
                    task?.resume()
                    
                    record.uploadTaskID = task?.taskIdentifier
                    try record.save(db)
                } catch {
                    print(error.localizedDescription)
                }
            }
        })
    }
    
    public func processLogTasks(tasks: [URLSessionUploadTask]) throws {
        var failedLogUploads: [LogFailure] = []
        try dbQueue?.inTransaction { db in
            for task in tasks {
                guard let record = try LogRecord.filter(Column("upload_task_id") == task.taskIdentifier).fetchOne(db) else { continue }
                if let httpResponse = task.response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        record.uploadTaskID = nil
                        // Tell our delegate we ran into trouble uploading the given logs
                        let logUploadFailure = LogFailure(task: task, response: httpResponse)
                        failedLogUploads.append(logUploadFailure)
                    }
                    try record.delete(db)
                }
            }

            return .commit
        }
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
