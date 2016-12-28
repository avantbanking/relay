///---

import Foundation

public protocol URLSessionProtocol {
    var configuration: URLSessionConfiguration { get }

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask
    
    func dataTask(with url: URL,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask
    

    func uploadTask(with request: URLRequest, from bodyData: Data?,
                    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionUploadTask
    

}

extension URLSession: URLSessionProtocol { }

public final class URLSessionMock : URLSessionProtocol {
    public var configuration: URLSessionConfiguration {
        return URLSessionConfiguration.background(withIdentifier: "inc.zerofinancial.logger")
    }
    
    var url: URL?
    var request: URLRequest?
    var taskResponse: (Data?, URLResponse?, Error?)?
    
    public init(data: Data?, response: URLResponse?, error: Error?) {
        taskResponse = (data, response, error)
    }
    
    public func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask {
        self.url = url
        let dataTaskMock = URLSessionDataTaskMock()
        dataTaskMock.taskResponse = taskResponse
        dataTaskMock.completionHandler = completionHandler

        return dataTaskMock
    }

    public func dataTask(with request: URLRequest,
                         completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask {
        self.request = request
        
        let dataTaskMock = URLSessionDataTaskMock()
        dataTaskMock.taskResponse = taskResponse
        dataTaskMock.completionHandler = completionHandler
    
        return dataTaskMock
    }
    

    public func uploadTask(with request: URLRequest, from bodyData: Data?,
                           completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionUploadTask {
        self.request = request
        
        let uploadTaskMock = URLSessionUploadTaskMock()
        uploadTaskMock.taskResponse = taskResponse
        uploadTaskMock.completionHandler = completionHandler
    
        return uploadTaskMock
    }

    private class URLSessionDataTaskMock : URLSessionDataTask {
        
        typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
        var completionHandler: CompletionHandler?
        var taskResponse: (Data?, URLResponse?, Error?)?
        
        override func resume() {
            completionHandler?(taskResponse?.0, taskResponse?.1, taskResponse?.2)
        }
    }
    
    private class URLSessionUploadTaskMock : URLSessionUploadTask {
        
        typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
        var completionHandler: CompletionHandler?
        var taskResponse: (Data?, URLResponse?, Error?)?
        
        override var taskIdentifier: Int { return 0 }

        
        override func resume() {
            completionHandler?(taskResponse?.0, taskResponse?.1, taskResponse?.2)
        }
    }
}

