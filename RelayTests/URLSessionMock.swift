///---

import Foundation

public protocol URLSessionProtocol {
    
    var configuration: URLSessionConfiguration { get }
    
    var delegate: URLSessionDelegate? { get }

    func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask
}

extension URLSession: URLSessionProtocol { }

public final class URLSessionMock : URLSessionProtocol {
    public var delegate: URLSessionDelegate?
    var latestTask: URLSessionTask?

    public func uploadTask(with request: URLRequest, from bodyData: Data) -> URLSessionUploadTask {
        self.request = request
        
        let uploadTaskMock = URLSessionUploadTaskMock(sessionDelegate: delegate as! URLSessionTaskDelegate)
        uploadTaskMock.taskResponse = taskResponse
        
        latestTask = uploadTaskMock
        
        return uploadTaskMock
    }

    public var configuration: URLSessionConfiguration {
        return URLSessionConfiguration.background(withIdentifier: "inc.zerofinancial.logger")
    }
    
    var url: URL?
    var request: URLRequest?
    var taskResponse: (Data?, URLResponse?, Error?)?
    var error: Error?
    
    public init(data: Data?, response: URLResponse?, error: Error?) {
        taskResponse = (data, response, error)
    }

    private class URLSessionUploadTaskMock : URLSessionUploadTask {
        
        var taskResponse: (Data?, URLResponse?, Error?)?
        
        override var response: URLResponse? { return taskResponse?.1 }
        
        weak var sessionDelegate: URLSessionTaskDelegate?
        
        override var taskIdentifier: Int { return 0 }
        
        override var error: Error? { return taskResponse?.2 }

        required init(sessionDelegate: URLSessionTaskDelegate) {
            self.sessionDelegate = sessionDelegate
        }

        
        override func resume() {
            DispatchQueue.main.async {
                self.sessionDelegate!.urlSession!(URLSession(), task: self, didCompleteWithError: nil)
            }
        }
    }
}

