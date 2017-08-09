//
//  RelayRemoteConfiguration.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


/// Configures the network settings used when uploading logs.
public struct RelayRemoteConfiguration: Equatable {

    public let host: URL

    public var httpHeaders: [String: String]
    
    public var successfulHTTPStatusCodes = [200]

    
    /// Generates a RelayRemoteConfiguration object
    ///
    /// - Parameters:
    ///   - host
    ///   - httpHeaders: If nil or if Content-Type or Accept are not defined,
    ///     they will default to application/json
    ///   - successfulHTTPStatusCodes: HTTP codes indicating a successful transmission. Defaults to 200.
    public init(host: URL, httpHeaders: [String: String]? = nil, successfulHTTPStatusCodes: [Int]? = nil) {
        self.host = host
        
        var headers: [String: String] = [:]
        if let httpHeaders = httpHeaders {
            headers = httpHeaders
            var contentTypeHeader = headers["Content-Type"]
            var acceptHeader = headers["Accept"]

            if contentTypeHeader == nil {
               contentTypeHeader = "application/json"
            }
            if acceptHeader == nil {
                acceptHeader = "application/json"
            }
            headers["Content-Type"] = contentTypeHeader
            headers["Accept"] = acceptHeader
        } else {
            headers = ["Content-Type": "application/json", "Accept": "application/json"]
        }
        self.httpHeaders = headers
        
        if let successfulHTTPStatusCodes = successfulHTTPStatusCodes {
            self.successfulHTTPStatusCodes = successfulHTTPStatusCodes
        }
    }
    
    // MARK: Equatable Protocol Methods
    
    public static func ==(lhs: RelayRemoteConfiguration, rhs: RelayRemoteConfiguration) -> Bool {
        if lhs.httpHeaders != rhs.httpHeaders {
            return false
        }
        
        return lhs.host == rhs.host
    }
}
