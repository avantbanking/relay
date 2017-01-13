//
//  RelayRemoteConfig.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


public struct RelayRemoteConfiguration: Equatable {
    public let host: URL
    public var additionalHttpHeaders: [String: String]?
    public init(host: URL, additionalHttpHeaders: [String: String]? = nil) {
        self.host = host
        self.additionalHttpHeaders = additionalHttpHeaders
    }
    
    // MARK: Equatable Protocol Methods
    
    public static func ==(lhs: RelayRemoteConfiguration, rhs: RelayRemoteConfiguration) -> Bool {
        if let lhsHeaders = lhs.additionalHttpHeaders, let rhsHeaders = rhs.additionalHttpHeaders, lhsHeaders != rhsHeaders {
            return false
        } else if (lhs.additionalHttpHeaders != nil && rhs.additionalHttpHeaders == nil) ||
            (rhs.additionalHttpHeaders != nil && lhs.additionalHttpHeaders == nil) {
            return false
        }
        
        return lhs.host == rhs.host
    }
}
