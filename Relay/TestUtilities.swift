//
//  TestUtilities.swift
//  Relay
//
//  Created by Evan Kimia on 1/10/17.
//  Copyright © 2017 zero. All rights reserved.
//

import Foundation

func isRunningUnitTests() -> Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
