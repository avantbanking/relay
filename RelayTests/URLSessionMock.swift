///---

import Foundation

public protocol URLSessionProtocol {
    
    var configuration: URLSessionConfiguration { get }
    
    var delegate: URLSessionDelegate? { get }

    func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask

    func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask

    func getAllTasks(completionHandler: @escaping ([URLSessionTask]) -> Swift.Void)
    
    func finishTasksAndInvalidate()
}

extension URLSession: URLSessionProtocol { }

public final class URLSessionMock : URLSessionProtocol {

    public var delegate: URLSessionDelegate?
    var url: URL?
    var request: URLRequest?
    var taskResponse: (Data?, URLResponse?, Error?)?
    var error: Error?
    var tasks: [URLSessionTask] = []
    public var taskResponseTime: TimeInterval = 0

    public func finishTasksAndInvalidate() { }
    
    public func getAllTasks(completionHandler: @escaping ([URLSessionTask]) -> Void) {
        completionHandler(tasks)
    }

    public func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        self.request = request
        
        let uploadTaskMock = URLSessionUploadTaskMock(session: self,
                                                      sessionDelegate: delegate as! URLSessionTaskDelegate,
                                                      request: request)
        uploadTaskMock.taskResponse = taskResponse
        uploadTaskMock.responseTime = taskResponseTime
        tasks.append(uploadTaskMock)
        
        return uploadTaskMock
    }
    
    public func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask {
        self.request = request
        
        let uploadTaskMock = URLSessionUploadTaskMock(session: self,
                                                      sessionDelegate: delegate as! URLSessionTaskDelegate,
                                                      request: request)
        uploadTaskMock.taskResponse = taskResponse
        uploadTaskMock.responseTime = taskResponseTime
        tasks.append(uploadTaskMock)
        
        return uploadTaskMock
    }

    public var configuration: URLSessionConfiguration {
        return URLSessionConfiguration.background(withIdentifier: "inc.zerofinancial.logger")
    }
    
    public init(data: Data?, response: URLResponse?, error: Error?) {
        taskResponse = (data, response, error)
    }

    private class URLSessionUploadTaskMock : URLSessionUploadTask {
        private var _currentRequest: URLRequest?
        override var currentRequest: URLRequest? { return _currentRequest }
        weak var session: URLSessionMock?
        var taskResponse: (Data?, URLResponse?, Error?)?
        var responseTime: TimeInterval = 0
        override var response: URLResponse? { return taskResponse?.1 }
        private var _taskIdentifier = Int(arc4random_uniform(100))
        weak private var sessionDelegate: URLSessionTaskDelegate?

        override var taskIdentifier: Int { return _taskIdentifier }
        override var error: Error? { return taskResponse?.2 }
        
        public override func cancel() {
            let when = DispatchTime.now() + responseTime
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.sessionDelegate!.urlSession!(URLSession(),
                                                  task: self,
                                                  didCompleteWithError: NSError(domain: "relayTests",
                                                                                code: NSURLErrorCancelled,
                                                                                userInfo: nil))
                guard let index = self.session?.tasks.index(of: self) else { return }
                self.session?.tasks.remove(at: index)
            }
        }

        required init(session: URLSessionMock?, sessionDelegate: URLSessionTaskDelegate, request: URLRequest?) {
            self.sessionDelegate = sessionDelegate
            self.session = session
            _currentRequest = request
        }
        
        override func resume() {
            let when = DispatchTime.now() + responseTime
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.sessionDelegate!.urlSession!(URLSession(), task: self, didCompleteWithError: nil)
                guard let index = self.session?.tasks.index(of: self) else { return }
                self.session?.tasks.remove(at: index)
            }
        }
    }
}

