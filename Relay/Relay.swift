//
//  Relay.swift
//  Relay
//
//  Created by Evan Kimia on 12/20/16.
//  Copyright © 2016 zero. All rights reserved.
//

import Foundation
import CocoaLumberjack
import RealmSwift
import Realm


public class Relay: DDAbstractLogger, URLSessionTaskDelegate {
    
    private var _identifier: String

    /// The relay identifier is used to segment different relays to different
    /// databases and act as identifiers for URLSessions. If you are using multiple
    /// relays, please use unique identifiers.
    public var identifier: String {
        return _identifier
    }
    
    /// The maximum amount of logs to store before older log records are discarded.
    /// Discarding logs will occur on the next log logged to the database.
    public var maxNumberOfLogs = 10000

    /// `RelayDelegate` is used to report successful/failed log uploads.
    public weak var delegate: RelayDelegate?
    
    /// The number of upload retries before the log is deleted.
    /// A nil value means it will retry indefinitely.
    public var uploadRetries = 3
    
    /// Internal database, marked as internal for use when running tests.
    var realm: Realm {
        let config = Realm.Configuration(fileURL: relayPath().appendingPathComponent(identifier + ".realm"), readOnly: false, schemaVersion: 1)
        do {
            return try Realm(configuration: config)
        } catch {
            fatalError("Error initializing Realm: \(error)")
        }
    }
    
    /// Represents the network connection settings used when firing off network tasks.
    /// Changing the host and/or additional headers will update pending log uploads
    /// automatically.
    public var configuration: RelayConfiguration {
        get {
            return _configuration
        }
        set {
            guard _configuration != newValue else { return }
            _configuration = newValue
            urlSession?.getAllTasks { [weak self] tasks in
                self?.recreatePendingUploadTasksIfNeeded(tasks: tasks)
            }
        }
    }

    /// Completion handler passed from the appDelegate's [application(_:handleEventsForBackgroundURLSession:completionHandler:) method](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1622941-application)
    var sessionCompletionHandler: (() -> Void)?

    /// The active session, confirming to URLSessionProtcol to aid in testing.
    var urlSession: URLSessionProtocol?
    
    private var _configuration: RelayConfiguration

    let writeQueue: OperationQueue = {
        let opq = OperationQueue()
        opq.qualityOfService = .utility
        
        return opq
    }()


    /// Initializes a relay.
    ///
    /// - Parameters:
    ///   - identifier: the identifier to be used for this relay. Each relay maintains it's own
    ///                 internal sqlite database for bookkeeping.
    ///
    ///   - configuration: see the documentation for `RelayConfiguration` for more information.
    ///
    ///   - testSession: only to be used when running tests!
    required public init(identifier: String, configuration: RelayConfiguration, testSession: URLSessionProtocol? = nil) {
        
        _identifier = identifier
        if testSession != nil && !isRunningUnitTests() {
            fatalError("testSession can only be used when running unit tests.")
        }
        self._configuration = configuration
        super.init()

        if testSession != nil {
            urlSession = testSession
        } else {
            let backgroundConfig = URLSessionConfiguration.background(withIdentifier: identifier)
            urlSession = URLSession(configuration: backgroundConfig,
                                    delegate: self,
                                    delegateQueue: nil)
        }
        
        cleanup()
    }
    

    func write(_ code: @escaping (_ realm: Realm) -> Void) {
        writeQueue.addOperation { [weak self] in
            guard let realm = self?.realm else { return }
            do {
                try realm.write() {
                    code(realm)
                }
            } catch {
                print("error writing object: \(error)")
            }
        }
    }


    /// Call in `application(_:handleEventsForBackgroundURLSession:completionHandler:)` in order
    /// for a relay to finish processing a log record once it succeeds/fails to upload. 
    ///
    /// - see also: [application(_:handleEventsForBackgroundURLSession:completionHandler:) documentation](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1622941-application)
    ///
    /// - Parameters:
    ///   - identifier: The identifier passed from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    ///                 If the identifer doesn't match the function will exit.
    ///
    ///   - completionHandler: The completion handler passed from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
    ///
    public func handleRelayUrlSessionEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == self.identifier else { return }
        sessionCompletionHandler = completionHandler
    }
    

    /// Removes all logs from the internal database. Logs already passed to the system for uploading will not be cancelled.
    public func reset(_ completion: (() -> Void)? = nil) {
        write() { realm in
            realm.deleteAll()
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.writeQueue.waitUntilAllOperationsAreFinished()

            completion?()
        }
    }
    
    
    /// Uploads all logs to the server.
    func flushLogs(_ completion: (() -> Void)? = nil) {
        write() { [weak self] realm in
            let logRecords = realm.objects(LogRecord.self).filter(NSPredicate(format: "_uploadTaskID == nil", argumentArray: nil))
            for record in logRecords {
                self?.uploadLogRecord(logRecord: record)
            }
            DispatchQueue.global(qos: .utility).async {
                completion?()
            }
        }
    }
    

    /// Helper function to create and upload an `URLSessionTask` to the server.
    ///
    /// - Parameters:
    ///   - logRecord: record to be uploaded.
    ///
    private func uploadLogRecord(logRecord: LogRecord) {
        do {
            let logUploadRequest: URLRequest = {
                var request = URLRequest(url: (configuration.host))
                request.httpMethod = "POST"
                for (headerName, headerValue) in configuration.httpHeaders {
                    request.setValue(headerValue, forHTTPHeaderField: headerName)
                }

                return request
            }()
            
            let jsonData = try JSONSerialization.data(withJSONObject: logRecord.dict)
            
            let fileURL = relayPath().appendingPathComponent("\(logRecord.uuid)")
            try jsonData.write(to: fileURL, options: .atomic)

            let task = urlSession?.uploadTask(with: logUploadRequest, fromFile: fileURL)
            
            logRecord.uploadTaskID = task?.taskIdentifier
            
            task?.resume()
        } catch {
            print("SQL error during upload process: \(error)")
        }
    }
    
    
    /// Checks pending tasks to ensure they have the appropriate settings from the current `RelayConfiguration`
    func recreatePendingUploadTasksIfNeeded(tasks: [URLSessionTask]) {
        
        /// Returns true if the task's request aligns with the current `RelayConfiguration`
        ///
        /// - Parameter task
        /// - Returns: Bool
        func checkTaskRequest(task: URLSessionTask) -> Bool {
            guard let request = task.currentRequest, let url = request.url else { return false }
            
            if let taskHeaders = request.allHTTPHeaderFields {
                for (key, value) in configuration.httpHeaders {
                    if let matchingRequestHeader = taskHeaders[key], matchingRequestHeader != value {
                        return false
                    } else if taskHeaders[key] == nil {
                        return false
                    }
                }
            } else if request.allHTTPHeaderFields == nil {
                    return false
            }
            
            return configuration.host == url
        }

        for task in tasks {
            guard !checkTaskRequest(task: task) else { return }
            write() { [weak self] realm in
                guard let record = realm.objects(LogRecord.self).filter("_uploadTaskID == %i", task.taskIdentifier).first else { return }
                task.cancel()
                
                self?.uploadLogRecord(logRecord: record)
            }
        }
    }
    
    
    /// Ensures a `LogRecord` does not have an uploadTaskID not associated with any `URLSessionTasks` in the session.
    func cleanup() {
        // Get our tasks from the session and ensure we dont have a log record associated with a nonexistent task.
        urlSession?.getAllTasks { [weak self] tasks in
            guard let this = self else { return }
            this.write() { realm in
                let logRecords = realm.objects(LogRecord.self).filter(NSPredicate(format: "_uploadTaskID != nil", argumentArray: nil))
                for record in logRecords {
                    if tasks.filter({ record.uploadTaskID == $0.taskIdentifier }).isEmpty {
                        record.uploadTaskID = nil
                         this.uploadLogRecord(logRecord: record)
                    }
                }
            }

            this.recreatePendingUploadTasksIfNeeded(tasks: tasks)
        }
    }
    
    private func deleteLogRecord(_ record: LogRecord) {
        deleteTempFile(forRecordUUID: record.uuid)
        realm.delete(record)
        if let delegate = delegate as? RelayTestingDelegate {
            delegate.relay(relay: self, didDeleteLogRecord: record)
        }
    }
    
    /// When a log succeeds or fails to upload, `processLogUploadTask` is called to do post processing.
    ///
    /// - Parameter task: The completed task.
    ///
    private func processLogUploadTask(task: URLSessionUploadTask, error: Error?) {
        write() { [weak self] realm in
            guard let this = self, let record = realm.objects(LogRecord.self).filter("_uploadTaskID == %i", task.taskIdentifier).first else { return }
            
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                this.deleteLogRecord(record)
                return
            }
            if let httpResponse = task.response as? HTTPURLResponse {
                if this.configuration.successfulHTTPStatusCodes.contains(httpResponse.statusCode) {
                    this.delegate?.relay(relay: this, didUploadLogMessage: record.logMessage)
                    if let delegate = this.delegate as? RelayTestingDelegate {
                        delegate.relay(relay: this, didUploadLogRecord: record)
                    }
                    
                    // Explicitly deleting the log record here instead of the deleteLogRecord method so the delegate doesn't get called.
                    this.deleteTempFile(forRecordUUID: record.uuid)
                    realm.delete(record)
                } else {
                    record.uploadTaskID = nil
                    record.uploadRetries += 1
                    // Should we toss it or try uploading it again?
                    if record.uploadRetries < this.uploadRetries {
                        this.uploadLogRecord(logRecord: record)
                    } else {
                        if let delegate = this.delegate as? RelayTestingDelegate {
                            delegate.relay(relay: this, didFailToUploadLogRecord: record, error: task.error, response: httpResponse)
                        }
                        this.delegate?.relay(relay: this, didFailToUploadLogMessage: record.logMessage, error: task.error, response: httpResponse)
                        
                        this.deleteLogRecord(record)
                    }
                }
            }
        }
    }
    
    
    /// Deletes a temporary file representing a `LogRecord`
    ///
    /// - Parameter record
    private func deleteTempFile(forRecordUUID uuid: String) {
        let fileURL = relayPath().appendingPathComponent("\(uuid)")
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("unable to delete temporary log file: \(error)")
        }
    }
    
    // MARK: URLSessionTaskDelegate Methods
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let task = task as? URLSessionUploadTask {
            processLogUploadTask(task: task, error: error)
        }
        sessionCompletionHandler?()
    }
    
    // MARK: DDAbstractLogger Methods
    
    override public func log(message logMessage: DDLogMessage) {
        // Generate a LogRecord from a LogMessage
        write { [weak self] realm in
            guard let this = self else { return }
            // Save it
            let record = LogRecord(logMessage: logMessage, loggerIdentifier: this.identifier)
            realm.add(record)
            let logRecordCount = realm.objects(LogRecord.self).count
            if logRecordCount > this.maxNumberOfLogs,
                let oldestLogRecord = realm.objects(LogRecord.self).sorted(byKeyPath: "_date", ascending: true).first {
                this.deleteLogRecord(oldestLogRecord)
            }
            this.flushLogs() {
                if let delegate = this.delegate as? RelayTestingDelegate {
                    delegate.relayDidFinishFlush(relay: this)
                }
            }
        }
    }
}
