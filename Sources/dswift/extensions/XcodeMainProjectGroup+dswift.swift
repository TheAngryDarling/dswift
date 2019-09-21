//
//  XcodeMainProjectGroup+dswift.swift
//  dswiftPackageDescription
//
//  Created by Tyler Anger on 2019-09-20.
//

import Foundation
import XcodeProj

internal extension XcodeGroup {
    // The relative path from the root of the project
    var relativePath: String {
        var path = self.fullPath
        let rootPath = self.mainGroup.fullPath
        if path.hasPrefix(rootPath) {
            path.removeFirst(rootPath.count)
        }
        if path.hasPrefix("/") { path.removeFirst() }
        return path
    }
}
internal extension XcodeMainProjectGroup {
    enum MainGroupErrors: Error, CustomStringConvertible {
        case groupFullPathMustStartWithSlash(String)
        
        var description: String {
            switch self {
            case .groupFullPathMustStartWithSlash(let path): return "Group Path '\(path)' must start with a slash(/)"
            }
        }
    }
    
    enum SubGroupGetOptions {
        case get
        case createIfNeed(createFolders: Bool, savePBXFile: Bool)
        
        public static var createAndSave: SubGroupGetOptions { return .createIfNeed(createFolders: true, savePBXFile: true) }
        public static var createOnly: SubGroupGetOptions { return .createIfNeed(createFolders: false, savePBXFile: false) }
    }
    
    /// Creates a sub group somehwere under the project
    ///
    /// - Parameters:
    ///   - path: The full path (from the project root) to the group (Must start with a slash(/) )
    ///   - createFolder: An indicator if a folder(s) on the file system shoud be created for this group (Default: true)
    ///   - savePBXFile: An indicator if the PBX Project File should be saved at this time (Default: true)
    /// - Returns: Returns the newly created group
    func createSubGroup(atPath path: String, createFolders: Bool = true, savePBXFile: Bool = true) throws -> XcodeGroup {
        guard path.hasPrefix("/") else { throw MainGroupErrors.groupFullPathMustStartWithSlash(path) }
        var groups: [String] = path.split(separator: "/").map(String.init)
        var currentGroup: XcodeGroup = self
        while groups.count > 0 {
            if let g = currentGroup.group(atPath: groups[0]) {
                currentGroup =  g
            } else {
                currentGroup = try currentGroup.createGroup(withName: groups[0],
                                                            createFolder: createFolders,
                                                            savePBXFile: savePBXFile)
            }
            
            groups.removeFirst()
        }
        return currentGroup
    }
    
    /// Get sub group at the given path.  If group doesn't exist and options is set to create, then this method will create the new sub group and required parents before returning the group
    /// - Parameter path: The full path (from the project root) to the group (Must start with a slash(/) )
    /// - Parameter options: Options on wether to just try and get the group, or create if doesn't exist
    func subGroup(atPath path: String, options: SubGroupGetOptions = .get) throws -> XcodeGroup? {
        if let g = self.group(atPath: path) { return g }
        guard case .createIfNeed(createFolders: let createFolders, savePBXFile: let savePBX) = options else { return nil }
        return try self.createSubGroup(atPath: path, createFolders: createFolders, savePBXFile: savePBX)
    }
}
