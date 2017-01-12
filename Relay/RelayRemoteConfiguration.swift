//
//  RelayRemoteConfig.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


public class RelayRemoteConfiguration {
    public let host: URL
    public var additionalHttpHeaders: [String: String]?
    required public init(host: URL, additionalHttpHeaders: [String: String]? = nil) {
        self.host = host
        self.additionalHttpHeaders = additionalHttpHeaders
    }
}
