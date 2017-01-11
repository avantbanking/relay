//
//  FrameworkUtilities.swift
//  Relay
//
//  Created by Evan Kimia on 1/9/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation


private func createRelayDirectoryIfNeeded() throws {
    // Create the Relay directory for our supporting files.
    try FileManager.default.createDirectory(at: relayPath(),
                                            withIntermediateDirectories: true,
                                            attributes: nil)
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
    let basePath: URL
    #if os(OSX)
        basePath = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
    #else
        basePath = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
    #endif
    
    return basePath.appendingPathComponent("relay")
}
