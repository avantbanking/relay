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
    public weak var delegate: RelayDelegate?
    public var uploadRetries = 3
    public var autoUpload = true
    var dbQueue: DatabaseQueue?
    private var identifier: String
    private var configuration: RelayRemoteConfiguration
    
    private static let urlSessionIdentifier = "zerofinancial.inc.logger"
    private var sessionCompletionHandler: (() -> Void)?
    
    private static var sharedUrlSession: URLSessionProtocol = {
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: Relay.urlSessionIdentifier)
        return URLSession(configuration: backgroundConfig)
    }()
    
    private var testSession: URLSessionProtocol?
    
    private var urlSession: URLSessionProtocol {
        if let testSession = testSession {
            return testSession
        } else {
            return Relay.sharedUrlSession
        }
    }
    
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
    required public init(identifier: String, configuration: RelayRemoteConfiguration, testSession: URLSessionProtocol? = nil) {
        
        self.identifier = identifier
        self.configuration = configuration
        if testSession != nil && !isRunningUnitTests() {
            fatalError("testSession can only be used when running unit tests.")
        }
        self.testSession = testSession
        
        do {
            
            dbQueue = try DatabaseQueue(path: try getRelayDirectory() + identifier + ".sqlite")
            
            try dbQueue?.inDatabase { db in
                guard try !db.tableExists(identifier) else { return }
                
                try db.create(table: LogRecord.TableName) { t in
                    t.column("uuid", .text).primaryKey()
                    t.column("message", .text)
                    t.column("flag", .integer).notNull()
                    t.column("level", .integer).notNull()
                    t.column("context", .text)
                    t.column("file", .text)
                    t.column("function", .text)
                    t.column("line", .integer)
                    t.column("date", .datetime)
                    t.column("upload_task_id", .integer)
                    t.column("upload_retries", .integer).notNull().defaults(to: 0)
                }
            }
        } catch {
            #if DEBUG
                fatalError("SQL error during initialization: \(error)")
            #endif
        }
        super.init()
        cleanup()
    }
    
    override init() {
        fatalError("Please use init(dbPath:) instead.")
    }
    
    public func handleRelayUrlSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == Relay.urlSessionIdentifier else { return }
        sessionCompletionHandler = completionHandler
    }
    
    func reset() throws {
        do {
            try dbQueue?.inDatabase({ db in
                try db.drop(table: identifier)
            })
        } catch {
            print("SQL error has occured when resetting the database: \(error)")
        }
    }
    
    func flushLogs() {
        do {
            try dbQueue?.inDatabase({ db in
                let logRecords = try LogRecord.filter(Column("upload_task_id") == nil).fetchAll(db)
                for record in logRecords {
                    do {
                        uploadLogRecord(logRecord: record, db: db)
                        try record.update(db)
                    } catch {
                        print(error)
                    }
                }
            })
        } catch {
            print("SQL error when flushing logs: \(error)")
        }
    }
    
    private func uploadLogRecord(logRecord: LogRecord, db: Database) {
        do {
            let logUploadRequest: URLRequest = {
                var request = URLRequest(url: configuration.host)
                if let additionalHTTPHeaders = configuration.additionalHttpHeaders {
                    for (headerName, headerValue) in additionalHTTPHeaders {
                        request.setValue(headerValue, forHTTPHeaderField: headerName)
                    }
                }
                return request
            }()
            
            let jsonData = try JSONSerialization.data(withJSONObject: logRecord.dict(),
                                                      options: .prettyPrinted)
            
            let task = urlSession.uploadTask(with: logUploadRequest, from: jsonData)
            
            logRecord.uploadTaskID = task.taskIdentifier
            try logRecord.update(db)
            task.resume()
        } catch {
            print("SQL error during upload process: \(error)")
        }
    }
    
    func cleanup() {
        // Get our tasks from the session and ensure we dont have a log record associated with a nonexistent task.
        urlSession.getAllTasks { [weak self] tasks in
            guard let this = self else { return }
            do {
                try this.dbQueue?.inTransaction { db in
                    for record in try LogRecord.filter(Column("upload_task_id") != nil).fetchAll(db) {
                        if tasks.flatMap({ record.uploadTaskID == $0.taskIdentifier }).first == nil {
                            record.uploadTaskID = nil
                            try record.update(db)
                            this.uploadLogRecord(logRecord: record, db: db)
                        }
                    }
                    
                    return .commit
                }
            } catch {
                print("SQL error cleaning up records: \(error)")
            }
        }
    }
    
    public func processLogUploadTask(task: URLSessionUploadTask) {
        do {
            try dbQueue?.inDatabase { db in
                guard let record = try LogRecord.filter(Column("upload_task_id") == task.taskIdentifier).fetchOne(db) else { return  }
                if let httpResponse = task.response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        record.uploadTaskID = nil
                        record.uploadRetries += 1
                        try record.update(db)
                        // Should we toss it or try uploading it again?
                        if record.uploadRetries < uploadRetries {
                            uploadLogRecord(logRecord: record, db: db)
                        } else {
                            try record.delete(db)
                        }
                        delegate?.relay(relay: self, didFailToUploadLogRecord: record, error: task.error, response: httpResponse)
                    } else {
                        try record.delete(db)
                        delegate?.relay(relay: self, didUploadLogRecord: record)
                    }
                }
            }
        } catch {
            print("SQL error processing log record: \(error)")
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = task as? URLSessionUploadTask {
            processLogUploadTask(task: task)
        }
        sessionCompletionHandler?()
    }
    
    // MARK: DDAbstractLogger Methods
    
    override public func log(message logMessage: DDLogMessage!) {
        // Generate a LogRecord from a LogMessage
        let logRecord = LogRecord(logMessage: logMessage, loggerIdentifier: identifier)
        do {
            try dbQueue?.inDatabase({ [weak self] db in
                try logRecord.save(db)
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    guard let this = self else { return }
                    if this.autoUpload {
                        this.flushLogs()
                    }
                }
            })
        } catch {
            print("SQL error saving log record to the database: \(error)")
        }
    }
}
