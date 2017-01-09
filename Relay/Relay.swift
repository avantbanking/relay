//
//  Relay.swift
//  Relay
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import Foundation
import GRDB
import CocoaLumberjack


public class Relay: DDAbstractLogger, URLSessionTaskDelegate {
    weak var delegate: RelayDelegate?
    var identifier: String
    var configuration: RelayRemoteConfiguration?
    var dbQueue: DatabaseQueue?
    var urlSession: URLSessionProtocol
    var uploadRetries = 3

    private let urlSessionIdentifier: String
    private let dbPath: String = "Documents/loggerdb.sqlite"
    

    /// Initializes the logger using GRDB to interface with SQLite, and your standard URLSession for uploading
    /// logs to the specified server.
    ///
    /// - Parameters:
    ///   - dbPath: Location for storing the database containing logs. Please be careful not to specify a nonpersistent
    ///   location for production use.
    ///
    ///   - configuration: Remote configuration for uploading logs. See the `persistentDictionary` method on `LogRecord` for information
    ///   on the JSON body and the `RelayRemoteConfiguration` class for options.
    ///
    ///   - session: session to use to upload the logs. If one is not provided a background session will be made
    ///
    /// - Throws: A DatabaseError is thrown whenever an SQLite error occurs. See the GRDB documentation here
    ///   for more information: https://github.com/groue/GRDB.swift#documentation
    ///
    required public init(identifier: String, configuration: RelayRemoteConfiguration? = nil, session: URLSessionProtocol? = nil) throws {
        
        self.identifier = identifier
        self.configuration = configuration

        dbQueue = try DatabaseQueue(path: dbPath)
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("Documents Directory: " + documentsPath)
        }
        
        if let session = session {
            urlSession = session
        } else {
            // Setup a background NSURLSession
            let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "zerofinancial.inc.logger")
            urlSession = URLSession(configuration: backgroundConfig)
        }
        
        urlSessionIdentifier = urlSession.configuration.identifier!
        
        try dbQueue?.inDatabase { db in
            guard try !db.tableExists(identifier) else { return }

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
                t.column("logger_identifier", .text)
                t.column("upload_retries", .integer).notNull().defaults(to: 0)
            }
        }
    }
    
    override init() {
        fatalError("Please use init(dbPath:) instead.")
    }
    
    func reset() throws {
        try dbQueue?.inDatabase({ db in
            try db.drop(table: identifier)
        })
    }
    
    typealias taskCompletion = (Data?, URLResponse?, Error?) -> Swift.Void
    
    func flushLogs() throws {
        try dbQueue?.inDatabase({ db in
            let logRecords = try LogRecord.filter(Column("upload_task_id") == nil).fetchAll(db)
            for record in logRecords {
                do {
                    let task = try uploadLogRecord(logRecord: record, db: db)
                    try record.update(db)
                } catch {
                    
                }
            }
        })
    }
    
    func uploadLogRecord(logRecord: LogRecord, db: Database) throws -> URLSessionUploadTask {
        let jsonData = try JSONSerialization.data(withJSONObject: logRecord.dict(), options: .prettyPrinted)
        let logUploadRequest = URLRequest(url: configuration!.host)
        let task = urlSession.uploadTask(with: logUploadRequest, from: jsonData)
        logRecord.uploadTaskID = task.taskIdentifier
        try logRecord.update(db)
        task.resume()

        return task
    }

    public func processLogUploadTask(task: URLSessionUploadTask) throws {
        try dbQueue?.inTransaction { db in
        guard let record = try LogRecord.filter(Column("upload_task_id") == task.taskIdentifier).fetchOne(db) else { return .commit }
        if let httpResponse = task.response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                record.uploadTaskID = nil
                delegate?.relay(relay: self, didFailToUploadLogRecord: record, error: task.error, response: httpResponse)
                // Should we toss it or try uploading it again?
                if record.uploadRetries < uploadRetries {
                    record.uploadRetries = record.uploadRetries + 1
                    try record.update(db)
                    print(record.hasPersistentChangedValues)
                    try uploadLogRecord(logRecord: record, db: db)
                } else {
                    try record.delete(db)
                }
                try record.update(db)
            } else {
                try record.delete(db)
                delegate?.relay(relay: self, didUploadLogRecord: record)
            }
        }

            return .commit
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = task as? URLSessionUploadTask {
            try! processLogUploadTask(task: task)
        }
    }
    
    // MARK: DDAbstractLogger Methods

    override public func log(message logMessage: DDLogMessage!) {
        // Generate a LogRecord from a LogMessage
        let logRecord = LogRecord(logMessage: logMessage, loggerIdentifier: identifier)
        try! dbQueue?.inDatabase({ db in
            try logRecord.insert(db)
        })
    }
}
