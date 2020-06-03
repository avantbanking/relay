//
//  Relay+Realm.swift
//  Relay
//
//  Created by Josh Wright on 6/21/18.
//  Copyright © 2018 zero. All rights reserved.
//

import Foundation
import RealmSwift
import CocoaLumberjackSwift


extension Relay {
    
    
    private var realmPath: URL {
        return relayPath().appendingPathComponent(identifier + ".realm")
    }
    
    
    /// Internal database, marked as internal for use when running tests.
    var realm: Realm {
        let config = Realm.Configuration(fileURL: realmPath,
                                         schemaVersion: 1,
                                         migrationBlock: migrationHandler,
                                         objectTypes:[LogRecord.self])
        do {
            return try Realm(configuration: config)
        } catch {
            // Nuke realm and try again
            DDLogError("Relay hit an error loading realm! Nuking it.")
            nukeRealm()
            do {
                return try Realm(configuration: config)
            } catch {
                fatalError("Relay hit an error loading realm, even after nuke!")
            }
        }
    }
    
    
    private func migrationHandler(_ migration: Migration, oldSchemaVersion: UInt64) {
        // 0 -> 1 did not require any migration code, but Realm demands a version bump
    }
    
    
    private func nukeRealm() {
        do {
            try FileManager.default.removeItem(at: realmPath)
        } catch {
            DDLogError("Error nuking Realm: \(error)")
        }
    }
}
