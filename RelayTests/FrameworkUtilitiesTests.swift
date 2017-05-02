//
//  FrameworkUtilitiesTests.swift
//  Relay
//
//  Created by Evan Kimia on 5/1/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation
import XCTest

@testable import Relay


class FrameworkUtilitiesTests: XCTestCase {

    func testGetRelayDirectory() {
        do { try FileManager.default.removeItem(at: relayPath()) } catch {}
        
        _ = try! getRelayDirectory()
        
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        if fileManager.fileExists(atPath: relayPath().path, isDirectory:&isDir) {
            if !isDir.boolValue {
                XCTFail("exists, but not a directory")
            }
        } else {
            XCTFail("directory does not exist.")
        }
    }
}
