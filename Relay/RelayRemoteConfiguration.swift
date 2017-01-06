//
//  RelayRemoteConfig.swift
//  Relay
//
//  Created by Evan Kimia on 1/6/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


public class RelayRemoteConfiguration {
    let host: URL
    var additionalHttpHeaders: [String: Any]?
    required public init(host: URL, additionalHttpHeaders: [String:Any]? = nil) {
        self.host = host
        self.additionalHttpHeaders = additionalHttpHeaders
    }
}
