//
//  SwiftProject.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2022-01-03.
//

import Foundation
import XcodeProj
import PathHelpers

/// Object representing a Swift project.
/// Stores the location of the Swift Project as well as the Xcode Project if one exists
public class SwiftProject {
    /// The location of the Swift project
    public let rootPath: FSPath
    /// The Xcode Project if one exists
    public let xcodeProject: XcodeProject?
    /// Indicator if there is an Xcode Project
    public var hasXcodeProject: Bool {
        return self.xcodeProject != nil
    }
    /// An array of Xcode Targets within the Xcode Project
    public var xcodeTargets: [XcodeTarget] {
        get { return self.xcodeProject?.targets ?? [] }
    }
    /// The Xcode Main Resource Group
    public var xcodeResources: XcodeMainProjectGroup! {
        get { return self.xcodeProject?.resources }
    }
    /// The Xcode Project System URL Resource
    public var xcodeProjectFolder: XcodeFileSystemURLResource? {
        get { return self.xcodeProject?.projectFolder }
    }
    
    /// Create a new Swift Project Object
    /// - Parameters:
    ///   - rootPath: The Path to the Swift Project
    ///   - xcodeProject: The Xcode Project if one exists
    public init(rootPath: FSPath,
                xcodeProject: XcodeProject? = nil) {
        self.rootPath = rootPath
        self.xcodeProject = xcodeProject
    }
    
    /// Create a new Swift Project Object
    /// - Parameters:
    ///   - rootPath: File File path to the Swift Project
    ///   - xcodeProject: The Xcode Project if one exists
    public convenience init(rootPath: String,
                            xcodeProject: XcodeProject? = nil) {
        
        self.init(rootPath: FSPath(rootPath),
                  xcodeProject: xcodeProject)
    }
    /// Save the Xcode Project
    public func saveXcodeProject() throws {
        try self.xcodeProject?.save()
    }
    
    /// Get the relative path of the givin path to the root of the Swift Project
    public func relativePath(for path: FSPath) -> FSPath {
        return path.relativePath(to: self.rootPath)
    }
    
    /// Get the Xcode File for the given path
    public func xcodeFile(at path: FSPath) -> XcodeFile? {
        return self.xcodeProject?.resources.file(atPath: self.relativePath(for: path).string)
    }
    
    /// Get the Xcode File for the given path
    public func xcodeFile(atPath path: String) -> XcodeFile? {
        return self.xcodeFile(at: FSPath(path))
    }
    
}
