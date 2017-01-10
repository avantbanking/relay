//
//  Utilities.swift
//  Relay
//
//  Created by Evan Kimia on 1/9/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


private func createRelayDirectoryIfNeeded() throws {
    // Create the Relay directory for our supporting files.
    try FileManager.default.createDirectory(at: relayPath(), withIntermediateDirectories: true, attributes: nil)
}

func getRelayDirectory() throws -> String {
    do {
        try createRelayDirectoryIfNeeded()
    } catch {
       // According to the documentation, checks to see if the operation will succeed first are discouraged.
    }

    return relayPath().absoluteString
}

func relayPath() -> URL {
    return NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]).appendingPathComponent("relay")!
}
