//
//  FileManager+PathHelpers.swift
//  
//
//  Created by Tyler Anger on 2022-04-24.
//

import Foundation

internal extension FileManager {
    
    #if swift(>=4.1) || os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        /// Returns a Boolean value that indicates whether a file or directory exists at a specified path. The isDirectory out parameter indicates whether the path points to a directory or a regular file.
        ///
        /// This is a wrapper around the fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool
        ///
        /// - Parameters:
        ///   - path: The path of a file or directory. If path begins with a tilde (~), it must first be expanded with expandingTildeInPath, or this method will return false.
        ///   - isDirectory: Upon return, contains true if path is a directory or if the final path element is a symbolic link that points to a directory; otherwise, contains false
        /// - Returns: true if a file at the specified path exists, or false if the file’s does not exist or its existence could not be determined.
        func fileExists(atPath path: String, isDirectory: inout Bool) -> Bool {
            var bool: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &bool) else { return false }
            
            isDirectory = bool.boolValue
            
            return true
        }
    #endif
}
