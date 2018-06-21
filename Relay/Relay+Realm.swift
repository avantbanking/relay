//
//  Relay+Realm.swift
//  Relay
//
//  Created by Josh Wright on 6/21/18.
//  Copyright © 2018 zero. All rights reserved.
//

import Foundation
import RealmSwift

extension Relay {
    
    /// Internal database, marked as internal for use when running tests.
    var realm: Realm {
        let config = Realm.Configuration(fileURL: relayPath().appendingPathComponent(identifier + ".realm"),
                                         schemaVersion: 1,
                                         migrationBlock: migrationHandler,
                                         objectTypes:[LogRecord.self])
        do {
            return try Realm(configuration: config)
        } catch {
            fatalError("Error initializing Realm: \(error)")
        }
    }
    
    private func migrationHandler(_ migration: Migration, oldSchemaVersion: UInt64) {
        // 0 -> 1 did not require any migration code, but Realm demands a version bump
    }
}
