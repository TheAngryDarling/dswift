//
//  FileManager+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2022-01-12.
//

import Foundation

internal extension FileManager {
    
    /// Sets the Posix Permission of a file
    /// - Parameters:
    ///   - permission: The permission to set
    ///   - path: The path to the file to set the permissions on
    func setPosixPermissions(_ permission: UInt, ofItemAtPath path: String) throws {
        try self.setAttributes([.posixPermissions: NSNumber(value: permission)],
                               ofItemAtPath: path)
    }
}
