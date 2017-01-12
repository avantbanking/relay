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
    
    static let urlSessionIdentifier = "zerofinancial.inc.logger"
    
    public weak var delegate: RelayDelegate?
    
    /// The number of upload retries before the log is deleted.
    /// A nil value means it will retry indefinitely.
    public var uploadRetries = 3
    
    /// When true logs will be immediately uploaded. If set to true
    /// and the app is in the background it will fall back to being 
    /// discretionary to the system.
    public var autoUpload = true
    
    /// Internal dbQueue, marked as internal for use when running tests.
    var dbQueue: DatabaseQueue?
    
    /// Represents the network connection settings used when firing off network tasks.
    /// Changing the host and/or additional headers will update pending log uploads
    /// automatically.
    public var configuration: RelayRemoteConfiguration

    var sessionCompletionHandler: (() -> Void)?
    
    /// The relay identifier is used to segment different relays to different
    /// databases.
    private var identifier: String
    
    
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
    
    /// Initializes a relay.
    ///
    /// - Parameters:
    ///   - identifier: the identifier to be used for this relay. Each relay maintains it's own
    ///                 internal sqlite database for bookkeeping.
    ///
    ///   - configuration: see the documentation for `RelayRemoteConfiguration` for more information.
    ///
    ///   - testSession: only to be used when running tests!
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
        fatalError("Please use init(_, _, _) instead.")
    }
    
    
    /// Call in `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in order
    /// for a relay to finish processing a log record once it succeeds/fails to upload. Take a
    /// look [here](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1622941-application)
    /// for more information.
    ///
    /// - Parameters:
    ///   - identifier: The identifier passed from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    ///                 If the identifer doesn't match the function will exit.
    ///
    ///   - completionHandler: The completion handler passed from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    ///
    public func handleRelayUrlSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == Relay.urlSessionIdentifier else { return }
        sessionCompletionHandler = completionHandler
    }
    

    /// Removes all logs from the internal database. Logs already passed to the system for uploading will not be cancelled.
    func reset() {
        do {
            try dbQueue?.inDatabase({ db in
                try db.drop(table: identifier)
            })
        } catch {
            print("SQL error has occured when resetting the database: \(error)")
        }
    }
    
    
    /// Uploads all logs to the server.
    public func flushLogs() {
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
    

    /// Helper function to create and upload an `URLSessionTask` to the server.
    ///
    /// - Parameters:
    ///   - logRecord: record to be uploaded.
    ///   - db: database instance.
    ///
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
            
            let fileURL = relayPath().appendingPathComponent("\(logRecord.uuid)")
            try jsonData.write(to: fileURL, options: .atomic)

            let task = urlSession.uploadTask(with: logUploadRequest, fromFile: fileURL)
            
            logRecord.uploadTaskID = task.taskIdentifier
            try logRecord.update(db)
            task.resume()
        } catch {
            print("SQL error during upload process: \(error)")
        }
    }
    
    
    /// Ensures a `LogRecord` does not have an uploadTaskID not associated with any `URLSessionTasks` in the session.
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
    
    /// When a log succeeds or fails to upload, `processLogUploadTask` is called to do post processing.
    ///
    /// - Parameter task: The completed task.
    ///
    private func processLogUploadTask(task: URLSessionUploadTask) {
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
                            deleteTempFile(forRecord: record)
                        }
                        delegate?.relay(relay: self, didFailToUploadLogRecord: record, error: task.error, response: httpResponse)
                    } else {
                        try record.delete(db)
                        deleteTempFile(forRecord: record)
                        delegate?.relay(relay: self, didUploadLogRecord: record)
                    }
                }
            }
        } catch {
            print("SQL error processing log record: \(error)")
        }
    }
    
    private func deleteTempFile(forRecord record: LogRecord) {
        let fileURL = relayPath().appendingPathComponent("\(record.uuid)")
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("unable to delete temporary log file: \(error)")
        }
    }
    
    // MARK: URLSessionTaskDelegate Methods
    
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
