//
//  URLSessionProtocol.swift
//  Relay
//
//  Created by Evan Kimia on 5/2/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


public protocol URLSessionProtocol {
    
    var delegate: URLSessionDelegate? { get }
    
    func uploadTask(with request: URLRequest, fromFile fileURL: URL) -> URLSessionUploadTask
    
    func getAllTasks(completionHandler: @escaping ([URLSessionTask]) -> Swift.Void)
}

extension URLSession: URLSessionProtocol { }
