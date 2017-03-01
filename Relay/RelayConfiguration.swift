//
//  RelayConfiguration.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


/// Configures the network settings used when uploading logs.
public struct RelayConfiguration: Equatable {

    public let host: URL

    public var httpHeaders: [String: String]

    
    /// Generates a RelayConfiguration object
    ///
    /// - Parameters:
    ///   - host
    ///   - additionalHttpHeaders: If nil or if Content-Type or Accept are not defined,
    ///                            they will default to application/json
    public init(host: URL, additionalHttpHeaders: [String: String]? = nil) {
        self.host = host
        
        var headers: [String: String] = [:]
        if let additionalHeaders = additionalHttpHeaders {
            headers = additionalHeaders
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
    }
    
    // MARK: Equatable Protocol Methods
    
    public static func ==(lhs: RelayConfiguration, rhs: RelayConfiguration) -> Bool {
        if lhs.httpHeaders != rhs.httpHeaders {
            return false
        }
        
        return lhs.host == rhs.host
    }
}
