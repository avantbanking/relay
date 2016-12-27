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
    private let taskMock: URLSessionTask
    
    public init(data: Data?, response: URLResponse?, error: Error?) {
        let dataTaskMock = URLSessionDataTaskMock()
        dataTaskMock.taskResponse = (data, response, error)
        
        self.taskMock = dataTaskMock
    }
    
    public func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask {
        let dataTaskMock = taskMock as! URLSessionDataTaskMock
        self.url = url
        dataTaskMock.completionHandler = completionHandler

        return dataTaskMock
    }

    public func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionDataTask {
        self.request = request
        let dataTaskMock = taskMock as! URLSessionDataTaskMock
        dataTaskMock.completionHandler = completionHandler
    
        return dataTaskMock
    }
    

    public func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) -> URLSessionUploadTask {
        self.request = request
        let uploadTaskMock = taskMock as! URLSessionUploadTaskMock
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
        
        override func resume() {
            completionHandler?(taskResponse?.0, taskResponse?.1, taskResponse?.2)
        }
    }
}

