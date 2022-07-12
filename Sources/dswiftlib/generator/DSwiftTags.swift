//
//  DSwiftTags.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2021-12-06.
//

import Foundation
import RegEx
import VersionKit
import PathHelpers

/// Protocol defining a DSwift Tag that references a folder
public protocol DSwiftFolderReferenceTag {
    /// The include file attribute value
    var path: FSRelativePath { get }
    /// The include file attribute absolute path
    var absolutePath: FSPath { get }
    /// List of extensions to include
    var includeExtensions: [FSExtension] { get }
    /// List of extenisons to exclude
    var excludeExtensions: [FSExtension] { get }
    /// A filter pattern used to only copy specific files
    var filter: RegEx? { get }
    /// Indicator if attributes should be propagated to child ReferenceFolders
    var propagateAttributes: Bool { get }
    /// Array of child folders
    var childFolders: [Self] { get }
}

/// Namespace containing objects related to DSwiftFolderReference
public enum DSwiftFolderReferenceObjects {
    
    /// Errors that can occur when working with DSwift Tags that implement DSwiftFolderReferenceTag
    public enum Errors: Swift.Error, CustomStringConvertible {
        case failedToGetContentsOfDir(path: String,
                                      error: Swift.Error)
        
        public var description: String {
            switch self {
                case .failedToGetContentsOfDir(path: let path,
                                               error: let err):
                return "Failed to get the content of the directory '\(path)': \(err)"
            }
        }
    }
    ///
    public enum ProcessResponse<R> {
        case `continue`
        case `return`(R)
    }
    
}






fileprivate extension DSwiftFolderReferenceTag {
    
    
    /// Method used to process files in folder and sub folders for specific files
    /// - Parameters:
    ///   - workingFolder: The working folder object that implements DSwiftFolderReferenceTag
    ///   - filters: Array of regular expressions to try and match agains each file
    ///   - source: The path to the current folder to look into
    ///   - root: The path to the original folder to look into
    ///   - includeExtensions: An array of file extensions to include.  Specifying will cause any other extension types to be ignored
    ///   - excludeExtensions: An array of file extensions to exclude
    ///   - parentAttributes: Attributes from the calling method
    ///   - fileManager: The file manager to use when searching for files
    ///   - combineAttributes: Closure to call when trying to combine parentAttributes with current DSwiftFolderReferenceTag object
    ///   - process: Closure used to process a file that matches the filter and extension criteria
    ///   - filePath: The path to the file to process
    /// - Returns: Returns the results returned from the process closure or nil if all files finished and no return from process
    static func processFolder<R,Attribs>(workingFolder: Self,
                                         filters: [RegEx],
                                         from source: FSPath,
                                         root: FSPath? = nil,
                                         includeExtensions: [FSExtension],
                                         excludeExtensions: [FSExtension],
                                         parentAttributes: Attribs? = nil,
                                         using fileManager: FileManager = .default,
                                         combineAttributes: (_ attributes: Attribs?,
                                                             _ current: Self) -> Attribs,
                                         process: (_ root: FSPath,
                                                   _ filePath: FSPath,
                                                   _ attributes: Attribs) throws -> DSwiftFolderReferenceObjects.ProcessResponse<R>) throws -> R? {
        
        
        let currentAttributes = combineAttributes(parentAttributes, workingFolder)
        
        let srcFolder = source
        //if !srcFolder.hasSuffix("/") { srcFolder += "/" }
        
        let root = root ?? srcFolder
        //if !root.hasSuffix("/") { root += "/" }
        
        let children: [FSPath]
        do {
            children = try srcFolder.contentsOfDirectory(using: fileManager)
            
        } catch {
            children = []
            throw DSwiftFolderReferenceObjects.Errors.failedToGetContentsOfDir(path: srcFolder.string,
                                                               error: error)
        }
        
        var subDirs: [FSPath] = []
        for child in children {
            guard let isDir = child.existsAndIsDirectory(using: fileManager) else {
                continue
            }
            if isDir {
                subDirs.append(child)
                continue
            }
            if !includeExtensions.isEmpty {
                guard let ext = child.extension else {
                    /// Skip because we have a include extensions but no extension was found
                    continue
                }
                if !includeExtensions.contains(ext) {
                    // Skip if we have include extensions and the current file does not
                    // have an extension in that list
                    continue
                }
            }
            if !excludeExtensions.isEmpty,
               let ext = child.extension,
               !includeExtensions.contains(ext) {
                // Skip if we have an exclude extension and the current file has
                // an extension in the list
                continue
            }
            
            if !filters.isEmpty &&
                !filters.contains(where: { return $0.firstMatch(in: child.string) != nil }) {
                // Skip if we have filters and we can't find a filter that matches
                // the given file
                continue
            }
            
            let ret = try process(root, child, currentAttributes)
            
            if case .return(let rtn) = ret {
                return rtn
            }
            
        }
        
        for child in subDirs {
            
            var subAttributes = currentAttributes
            var wif = workingFolder
            var fltrs = filters
            var inclExtensions = includeExtensions
            var exclExtensions = excludeExtensions
            if let nwif = wif.childFolders.first(where: {
                return $0.absolutePath == child }) {
                wif = nwif
                
                if nwif.propagateAttributes {
                
                    
                    if let f = nwif.filter {
                        if !fltrs.contains(where: { return $0.pattern == f.pattern }) {
                            fltrs.append(f)
                        }
                    }
                    
                    for ext in nwif.includeExtensions {
                        if !inclExtensions.contains(ext) {
                            inclExtensions.append(ext)
                        }
                    }
                    for ext in nwif.excludeExtensions {
                        if !exclExtensions.contains(ext) {
                            exclExtensions.append(ext)
                        }
                    }
                    
                    subAttributes = combineAttributes(currentAttributes, nwif)
                    
                } else {
                    fltrs = []
                    if let f = nwif.filter { fltrs.append(f) }
                    inclExtensions = nwif.includeExtensions
                    exclExtensions = nwif.excludeExtensions
                    subAttributes = combineAttributes(nil, nwif)
                }
            }
            
            if let ret = try processFolder(workingFolder: wif,
                                           filters: fltrs,
                                           from: child,
                                           root: root,
                                           includeExtensions: inclExtensions,
                                           excludeExtensions: exclExtensions,
                                           parentAttributes: subAttributes,
                                           using: fileManager,
                                           combineAttributes: combineAttributes,
                                           process: process) {
                return ret
            }
            
        }
        
        return nil
        
    }
    
    /// Method used to process files in folder and sub folders for specific files
    /// - Parameters:
    ///   - fileManager: The file manager to use when searching for files
    ///   - combineAttributes: Closure to call when trying to combine parentAttributes with current DSwiftFolderReferenceTag object
    ///   - process: Closure used to process a file that matches the filter and extension criteria
    ///   - rootPath: The path to the original folder to look into
    ///   - filePath: The path to the file to process
    /// - Returns: Returns the results returned from the process closure or nil if all files finished and no return from process
    func processFolder<R, Attribs>(using fileManager: FileManager = .default,
                                   combineAttributes: (_ attributes: Attribs?,
                                                       _ current: Self) -> Attribs,
                                   process: (_ rootPath: FSPath,
                                             _ filePath: FSPath,
                                             _ attribs: Attribs) throws -> DSwiftFolderReferenceObjects.ProcessResponse<R>) throws -> R? {
        
        var filters: [RegEx] = []
        if let filter = self.filter { filters.append(filter) }
        return try Self.processFolder(workingFolder: self,
                                      filters: filters,
                                      from: self.absolutePath,
                                      includeExtensions: self.includeExtensions,
                                      excludeExtensions: self.excludeExtensions,
                                      parentAttributes: nil,
                                      using: fileManager,
                                      combineAttributes: combineAttributes,
                                      process: process)
    }
    
    
    
    /// Method used to process files in folder and sub folders for specific files
    /// - Parameters:
    ///   - fileManager: The file manager to use when searching for files
    ///   - process: Closure used to process a file that matches the filter and extension criteria
    ///   - rootPath: The path to the original folder to look into
    ///   - filePath: The path to the file to process
    /// - Returns: Returns the results returned from the process closure or nil if all files finished and no return from process
    func processFolder<R>(using fileManager: FileManager = .default,
                          process: @escaping (_ rootPath: FSPath,
                                              _ filePath: FSPath) throws -> DSwiftFolderReferenceObjects.ProcessResponse<R>) throws -> R? {
        func combineAttributes(parentAttribs: Void?, currentFolder: Self) -> Void {
            return ()
        }
        func realProcess(rootPath: FSPath,
                         filePath: FSPath,
                         attribs: Void) throws -> DSwiftFolderReferenceObjects.ProcessResponse<R> {
            return try process(rootPath, filePath)
        }
        
        var filters: [RegEx] = []
        if let filter = self.filter { filters.append(filter) }
        return try Self.processFolder(workingFolder: self,
                                      filters: filters,
                                      from: self.absolutePath,
                                      includeExtensions: self.includeExtensions,
                                      excludeExtensions: self.excludeExtensions,
                                      parentAttributes: nil,
                                      using: fileManager,
                                      combineAttributes: combineAttributes,
                                      process: realProcess)
    }
    
    /// Method used to process files in folder and sub folders for specific files
    /// - Parameters:
    ///   - fileManager: The file manager to use when searching for files
    ///   - process: Closure used to process a file that matches the filter and extension criteria
    ///   - rootPath: The path to the original folder to look into
    ///   - filePath: The path to the file to process
    func processFolder<Attribs>(using fileManager: FileManager = .default,
                                combineAttributes: (_ attributes: Attribs?,
                                                    _ current: Self) -> Attribs,
                                process: @escaping (_ rootPath: FSPath,
                                                    _ filePath: FSPath,
                                                    _ attribs: Attribs) throws -> Void) throws {
        
        var filters: [RegEx] = []
        if let filter = self.filter { filters.append(filter) }
        func realProcess(rootPath: FSPath,
                         filePath: FSPath,
                         attribs: Attribs) throws -> DSwiftFolderReferenceObjects.ProcessResponse<Void> {
            try process(rootPath, filePath, attribs)
            return .continue
        }
        try Self.processFolder(workingFolder: self,
                               filters: filters,
                               from: self.absolutePath,
                               includeExtensions: self.includeExtensions,
                               excludeExtensions: self.excludeExtensions,
                               parentAttributes: nil,
                               using: fileManager,
                               combineAttributes: combineAttributes,
                               process: realProcess)
    }
    
    /// Method used to process files in folder and sub folders for specific files
    /// - Parameters:
    ///   - fileManager: The file manager to use when searching for files
    ///   - process: Closure used to process a file that matches the filter and extension criteria
    ///   - rootPath: The path to the original folder to look into
    ///   - filePath: The path to the file to process
    func processFolder(using fileManager: FileManager = .default,
                       process: @escaping (_ rootPath: FSPath,
                                           _ filePath: FSPath) throws -> Void) throws {
        
        var filters: [RegEx] = []
        if let filter = self.filter { filters.append(filter) }
        func combineAttributes(parentAttribs: Void?, currentFolder: Self) -> Void {
            return ()
        }
        func realProcess(rootPath: FSPath,
                         filePath: FSPath,
                         attribs: Void) throws -> DSwiftFolderReferenceObjects.ProcessResponse<Void> {
            try process(rootPath, filePath)
            return .continue
        }
        try Self.processFolder(workingFolder: self,
                               filters: filters,
                               from: self.absolutePath,
                               includeExtensions: self.includeExtensions,
                               excludeExtensions: self.excludeExtensions,
                               parentAttributes: nil,
                               using: fileManager,
                               combineAttributes: combineAttributes,
                               process: realProcess)
    }
}

public extension DSwiftFolderReferenceTag {
    /// Checks to see if the tag reference has external resources
    /// That has been modified since the given date
    func hasBeenModified(since date: Date,
                         using fileManager: FileManager = .default,
                         console: Console = .null) throws -> Bool {
        
        func shouldRebuild(rootPath: FSPath,
                           filePath: FSPath) throws -> DSwiftFolderReferenceObjects.ProcessResponse<Bool> {
            do {
                guard let modDate = try filePath.modificationDate(using: fileManager) else {
                    return .return(true)
                }
                if modDate > date {
                    return .return(true)
                } else {
                    return .continue
                }
            } catch {
                console.printError("Failed to get modification date of '\(filePath)': \(error)", object: self)
                return .return(true)
            }
        }
        if let ret = try self.processFolder(using: fileManager,
                                            process: shouldRebuild) {
            return ret
        }
        
        return false
    }
}

public protocol DSwiftFileReferenceTag {
    /// The tag value path
    var path: FSRelativePath { get }
    /// The absolute path value
    var absolutePath: FSPath { get }
}

public extension DSwiftFileReferenceTag {
    /// Checks to see if the tag reference has external resources
    /// That has been modified since the given date
    /// - Parameters:
    ///   - date: The date to see if modification has occured since
    ///   - fileManager: The file manager to use when accessing file information
    ///   - console: The object used to print to the console
    /// - Returns: Returns if any modifications have occured sine the given date
    func hasBeenModified(since date: Date,
                         using fileManager: FileManager = .default,
                         console: Console = .null) throws -> Bool {
        
        guard let modDate = try self.absolutePath.modificationDate(using: fileManager) else {
            return true
        }
        guard modDate <= date else {
            return true
        }
        return false
        
    }
}
/// Enum containing the different type of DSwift Tags
public enum DSwiftTag {
    
    /// The minimum dswift version required to support any tags
    public static var minimumSupportedTagVersion: Version.SingleVersion = "1.0.18"
    /// The minimum dswift version required to support any tags
    fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
        return DSwiftTag.minimumSupportedTagVersion
    }
    
    
    /// Enum containing the different type of DSwift Reference Tags
    public enum Reference {
        /// The minimum dswift version required to support any tags
        public static var minimumSupportedTagVersion: Version.SingleVersion = "2.0.0"
        /// The minimum dswift version required to support any tags
        fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
            return DSwiftTag.minimumSupportedTagVersion
        }
        /// An object defining a File Reference Tag
        public struct File: DSwiftFileReferenceTag {
            /// The identifiable attribute for this subtag
            public static let identifierAttribute = "file"
            /// The name of the tag
            public let tagName: String
            /// The tag value path
            public let path: FSRelativePath
            /// The absolute path value
            public let absolutePath: FSPath
            
            /// Method to check if attributes has the main required attribute to parse
            fileprivate static func isFileTag(_ attributes: [String: String]) -> Bool {
                return attributes[identifierAttribute] != nil
            }
            
        }
        /// An object defining a Folder Reference Tag
        public struct Folder: DSwiftFolderReferenceTag {
            
            /// The identifiable attribute for this subtag
            public static let identifierAttribute = "folder"
            
            /// The name of the tag
            public let tagName: String
            /// The include file attribute value
            public let path: FSRelativePath
            /// The include file attribute absolute path
            public let absolutePath: FSPath
            /// List of extensions to include
            public let includeExtensions: [FSExtension]
            /// List of extenisons to exclude
            public let excludeExtensions: [FSExtension]
            /// A filter pattern used to only copy specific files
            public let filter: RegEx?
            /// Indicator if attributes should be propagated to child ReferenceFolders
            public let propagateAttributes: Bool
            /// Array of child folders with specific rules
            public var childFolders: [Folder] = []
            
            /// Method to check if attributes has the main required attribute to parse
            fileprivate static func isFileTag(_ attributes: [String: String]) -> Bool {
                return attributes[identifierAttribute] != nil
            }
        }
        
        case file(File)
        case folder(Folder)
        
        /// The name of the tag
        public var tagName: String {
            switch self {
                case .file(let f): return f.tagName
                case .folder(let f): return f.tagName
            }
        }
        
        /// The include file attribute value
        public var path: FSRelativePath {
            switch self {
                case .file(let rtn): return rtn.path
                case .folder(let rtn): return rtn.path
            }
        }
        /// The include file attribute absolute path
        public var absolutePath: FSPath {
            switch self {
                case .file(let rtn): return rtn.absolutePath
                case .folder(let rtn): return rtn.absolutePath
            }
        }
        
        
        /// Checks to see if the tag reference has external resources
        /// That has been modified since the given date
        /// - Parameters:
        ///   - date: The date to see if modification has occured since
        ///   - fileManager: The file manager to use when accessing file information
        ///   - console: The object used to print to the console
        /// - Returns: Returns if any modifications have occured sine the given date
        public func hasBeenModified(since date: Date,
                                    using fileManager: FileManager = .default,
                                    console: Console = .null) throws -> Bool {
            switch self {
                case .file(let f):
                    return try f.hasBeenModified(since: date,
                                                 using: fileManager,
                                                 console: console)
                case .folder(let f):
                    return try f.hasBeenModified(since: date,
                                                 using: fileManager,
                                                 console: console)
            }
        }
    }
    /// Enum containing the different type of DSwift Reference Tags
    public enum Include {
        
        /// The minimum dswift version required to support any tags
        public static var minimumSupportedTagVersion: Version.SingleVersion {
            return DSwiftTag.minimumSupportedTagVersion // = "1.0.18"
        }
        /// The minimum dswift version required to support any tags
        fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
            return DSwiftTag.minimumSupportedTagVersion
        }
        /// An object defining a File Include Tag
        public struct File: DSwiftFileReferenceTag {
            /// The minimum dswift version required to support any tags
            public static var minimumSupportedTagVersion: Version.SingleVersion {
                return Include.minimumSupportedTagVersion // = "1.0.21"
            }
            /// The minimum dswift version required to support any tags
            fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
                return DSwiftTag.minimumSupportedTagVersion
            }
            
            /// The identifiable attribute for this subtag
            public static let identifierAttribute = "file"
            /// The name of the tag
            public let tagName: String
            /// The include file attribute value
            public let path: FSRelativePath
            /// The include file attribute absolute path
            public let absolutePath: FSPath
            /// The include onlyOnce attribute value
            public let includeOnlyOnce: Bool
            /// Indicator if the onlyOnce attribute was set
            public let includeOnlyAttributeSet: Bool
            /// Indicator if include comment blocks should be visible or not
            public let disableIncludeCommentBlocks: Bool
            
            /// Method to check if attributes has the main required attribute to parse
            fileprivate static func isFileTag(_ attributes: [String: String]) -> Bool {
                return attributes[identifierAttribute] != nil
            }
            
            public static func ==(lhs: File, rhs: File) -> Bool {
                return lhs.path == rhs.path &&
                       lhs.absolutePath == rhs.absolutePath &&
                       lhs.includeOnlyOnce == rhs.includeOnlyOnce &&
                       lhs.includeOnlyAttributeSet == rhs.includeOnlyAttributeSet &&
                       lhs.disableIncludeCommentBlocks == rhs.disableIncludeCommentBlocks
            }
            
            /// Checks to see if the tag reference has external resources
            /// That has been modified since the given date
            /// - Parameters:
            ///   - date: The date to see if modification has occured since
            ///   - fileManager: The file manager to use when accessing file information
            ///   - console: The object used to print to the console
            /// - Returns: Returns if any modifications have occured sine the given date
            public func hasBeenModified(since date: Date,
                                        using fileManager: FileManager = .default,
                                        console: Console = .null) throws -> Bool {
                
                guard let modDate = try self.absolutePath.modificationDate(using: fileManager) else {
                    return true
                }
                guard modDate <= date else {
                    return true
                }
                return false
            }
        }
        /// An object defining a Folder Include Tag
        public struct Folder: DSwiftFolderReferenceTag {
            
            /// The minimum dswift version required to support any tags
            public static var minimumSupportedTagVersion: Version.SingleVersion = "2.0.0"
            /// The minimum dswift version required to support any tags
            fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
                return DSwiftTag.minimumSupportedTagVersion
            }
            
            /// The identifiable attribute for this subtag
            public static let identifierAttribute = "folder"
            /// The name of the tag
            public let tagName: String
            /// The include file attribute value
            public let path: FSRelativePath
            /// The include file attribute absolute path
            public let absolutePath: FSPath
            /// List of extensions to include
            public let includeExtensions: [FSExtension]
            /// List of extenisons to exclude
            public let excludeExtensions: [FSExtension]
            /// The extension Mapping to occur when copying files
            public var extensionMapping: [FSExtension: FSExtension]
            /// A filter pattern used to only copy specific files
            public let filter: RegEx?
            /// Indicator if attributes should be propagated to child IncludedFolders
            public let propagateAttributes: Bool
            /// Indicator if include comment blocks should be visible or not
            public let disableIncludeCommentBlocks: Bool
            /// Array of child folders with specific rules
            public var childFolders: [Folder]
            
            /// Method to check if attributes has the main required attribute to parse
            fileprivate static func isFileTag(_ attributes: [String: String]) -> Bool {
                return attributes[identifierAttribute] != nil
            }
            
            public static func root(currentChildren: [Folder] = []) -> Folder {
                //let source = ""
                return Folder(tagName: "",
                              path: .init(""),
                              absolutePath: .root,
                              includeExtensions: [],
                              excludeExtensions: [],
                              extensionMapping: [:],
                              filter: nil,
                              propagateAttributes: false,
                              disableIncludeCommentBlocks: true,
                              childFolders: currentChildren)
            }
            
            /// Add chlid folder rules to the the given parent folder
            /// - Parameter folder: The child folder rules to add
            public mutating func appendChildFolder(_ folder: Folder) {
                precondition(folder.absolutePath.isChildPath(of: self.absolutePath),
                             "Child folder '\(folder.absolutePath)' does not fall under current path '\(self.absolutePath)'")
                
                // See if we have a child with the same absolute path
                if let idx = self.childFolders.firstIndex(where: { return $0.absolutePath == folder.absolutePath}) {
                    var f = self.childFolders[idx]
                    for (k,v) in folder.extensionMapping {
                        f.extensionMapping[k] = f.extensionMapping[k] ?? v
                    }
                    f.appendChildFolders(folder.childFolders)
                } else if let idx = self.childFolders.firstIndex(where: { return folder.absolutePath.isChildPath(of: $0.absolutePath) }) {
                    // See if this folder falls under one of our child folders
                    self.childFolders[idx].appendChildFolder(folder)
                } else if let idx = self.childFolders.firstIndex(where: { return $0.absolutePath.isChildPath(of: folder.absolutePath) }) {
                    // See if this folder is a parent to any child folders we currently have
                    var f = folder
                    f.appendChildFolder(self.childFolders[idx])
                    self.childFolders.remove(at: idx)
                    while let idx = self.childFolders.firstIndex(where: { return $0.absolutePath.isChildPath(of: folder.absolutePath) }) {
                        f.appendChildFolder(self.childFolders[idx])
                        self.childFolders.remove(at: idx)
                    }
                    self.childFolders.insert(f, at: idx)
                } else {
                    // Since this folder is neither a child or parent to any children of ours
                    // we add it as a child to ourself
                    self.childFolders.append(folder)
                    self.childFolders.sort(by: { return $0.absolutePath < $1.absolutePath })
                }
            }
            
            /// Add a list of child folder rules to the given parent folder
            /// - Parameter folders: An array of child folder rules to add
            public mutating func appendChildFolders(_ folders: [Folder]) {
                for f in folders {
                    self.appendChildFolder(f)
                }
            }
            /// Errors that can occur when trying to copy files to new location when building sub project to compile dswift file
            public enum CopyFilesError: Swift.Error, CustomStringConvertible {
                case failedToCreateDirectory(path: String, error: Swift.Error)
                case failedToCopyFile(from: String, to: String, error: Swift.Error)
                
                public var description: String {
                    switch self {
                        case .failedToCreateDirectory(path: let path,
                                                      error: let err):
                            return "Failed to create directory '\(path)': \(err)"
                        case .failedToCopyFile(from: let fromPath,
                                               to: let toPath,
                                               error: let err):
                            return "Failed to copy file from '\(fromPath)' to '\(toPath)': \(err)"
                    }
                }
                
            }
            public func copyFiles(to destination: FSPath,
                                  console: Console = .null,
                                  using fileManager: FileManager = .default) throws -> Int {
                var copyCount: Int = 0
                func combineAttributes(extMappings: [FSExtension: FSExtension]?,
                                 parent: Folder) -> [FSExtension: FSExtension] {
                    guard let attribs = extMappings else {
                        return parent.extensionMapping
                    }
                    var rtn = attribs
                    for (k,v) in parent.extensionMapping {
                        rtn[k] = rtn[k] ?? v
                    }
                    return rtn
                }
                func copyFile(rootPath: FSPath,
                              filePath: FSPath,
                              extMappings: [FSExtension: FSExtension]) throws -> Void  {
                    guard let relativePath = filePath.relative(to: rootPath) else {
                        return
                    }
                    
                    //var destPath = FSPath.init(relativePath, relativeToPath: destination)
                    var destPath = destination + relativePath
                    
                    
                    if let ext = destPath.extension,
                       let newExt = extMappings[ext] {
                        destPath = destPath.deletingExtension().appendingExtension(newExt)
                    }
                    
                    let destFolder = destPath.deletingLastComponent()
                    if !destFolder.exists(using: fileManager) {
                        do {
                            console.printVerbose("Creating destination folder '\(destPath)'", object: self)
                            try destFolder.createDirectory(withIntermediateDirectories: true,
                                                           using: fileManager)
                            console.printVerbose("Created destination folder '\(destFolder)'", object: self)
                        } catch {
                            throw CopyFilesError.failedToCreateDirectory(path: destFolder.string,
                                                                         error: error)
                        }
                    }
                    
                    do {
                        console.printVerbose("Copying item from '\(filePath)' to '\(destPath)'", object: self)
                        try filePath.copy(to: destPath, using: fileManager)
                        copyCount += 1
                        console.printVerbose("Copied item from '\(filePath)' to '\(destPath)'", object: self)
                    } catch {
                        throw CopyFilesError.failedToCopyFile(from: filePath.string,
                                                              to: destPath.string,
                                                              error: error)
                    }
                    
                }
                try self.processFolder(using: fileManager,
                                       combineAttributes: combineAttributes,
                                       process: copyFile)
                return copyCount
            }
            
            
        }
        /// An object defining a Git Package Include Tag
        public struct GitPackageDependency {
            
            public enum Requirements {
                case from(Version.SingleVersion)
                case closedRange(lowerBound: Version.SingleVersion, upperBound: Version.SingleVersion)
                case range(lowerBound: Version.SingleVersion, upperBound: Version.SingleVersion)
                
                case exact(Version.SingleVersion)
                case branch(String)
                case revision(String)
                
                public var displayDetails: String {
                    switch self {
                        case .from(let val):
                            return "From: \"\(val.fullDescription)\""
                        case .closedRange(let lower, let upper):
                            return "Range: \"\(lower.fullDescription)\"...\"\(upper.fullDescription)\""
                        case .range(let lower, let upper):
                            return "Range: \"\(lower.fullDescription)\"..<\"\(upper.fullDescription)\""
                        case .exact(let val):
                            return "Exact: \"\(val.fullDescription)\""
                        case .branch(let val):
                            return "Branch: \"\(val)\""
                        case .revision(let val):
                            return "Revision: \"\(val)\""
                    }
                }
                public var tag: String {
                    switch self {
                        case .from(let val):
                            return "from: \"\(val.fullDescription)\""
                        case .closedRange(let lower, let upper):
                            return "\"\(lower.fullDescription)\"...\"\(upper.fullDescription)\""
                        case .range(let lower, let upper):
                            return "\"\(lower.fullDescription)\"..<\"\(upper.fullDescription)\""
                        case .exact(let val):
                            return ".exact(\"\(val.fullDescription)\")"
                        case .branch(let val):
                            return ".branch(\"\(val)\")"
                        case .revision(let val):
                            return ".revision(\"\(val)\")"
                    }
                }
            }
            /// The minimum dswift version required to support any tags
            public static var minimumSupportedTagVersion: Version.SingleVersion = "2.0.0"
            /// The minimum dswift version required to support any tags
            fileprivate var minimumSupportedTagVersion: Version.SingleVersion {
                return DSwiftTag.minimumSupportedTagVersion
            }
            
            /// The identifiable attribute for this subtag
            public static let identifierAttribute = "package"
            /// The name of the tag
            public let tagName: String
            /// The url of the package
            public let url: String
            /// The Package Requierments
            public let requirements: Requirements
            /// The package names to import
            public let packageNames: [String]
            /// Indicator if include comment blocks should be visible or not
            public let disableIncludeCommentBlocks: Bool
            
            /// Method to check if attributes has the main required attribute to parse
            fileprivate static func isFileTag(_ attributes: [String: String]) -> Bool {
                return attributes[identifierAttribute] != nil
            }
            
            /// Checks to see if the tag reference has external resources
            /// That has been modified since the given date
            /// - Parameters:
            ///   - date: The date to see if modification has occured since
            ///   - fileManager: The file manager to use when accessing file information
            ///   - console: The object used to print to the console
            /// - Returns: Returns if any modifications have occured sine the given date
            public func hasBeenModified(since date: Date,
                                        using fileManager: FileManager = .default,
                                        console: Console = .null) throws -> Bool {
                return false
            }
        }
        
        case file(File)
        case folder(Folder)
        case packageDependency(GitPackageDependency)
        
        /// Returns the IncludeFile object if this incldue is a file include.  Otherwise returnsn nil
        public var includedFile: File? {
            guard case .file(let rtn) = self else { return nil }
            return rtn
        }
        /// Returns the IncludeFolder object if this include is a folder include.  Otherwise returnsn nil
        public var includedFolder: Folder? {
            guard case .folder(let rtn) = self else { return nil }
            return rtn
        }
        
        /// Returns the IncludePackageDependency object if this include is a package dependency include.  Otherwise returnsn nil
        public var includedPackageDependency: GitPackageDependency? {
            guard case .packageDependency(let rtn) = self else { return nil }
            return rtn
        }
        /// Returns a bool indicator if this is an IncludeFile include
        public var isIncludedFile: Bool { return self.includedFile != nil }
        /// Returns a bool indicator if this is an IncludeFolder include
        public var isIncludedFolder: Bool { return self.includedFolder != nil }
        /// Returns a bool indicator if this is an IncludePackageDependency include
        public var isIncludedPackageDependency: Bool {
            return self.includedPackageDependency != nil
        }
        
        /// The name of the tag
        public var tagName: String {
            switch self {
                case .file(let f): return f.tagName
                case .folder(let f): return f.tagName
                case .packageDependency(let p): return p.tagName
            }
        }
        
        /// The include file attribute value
        public var includePath: String {
            switch self {
                case .file(let rtn): return rtn.path.string
                case .folder(let rtn): return rtn.path.string
                case .packageDependency(let rtn): return rtn.url
            }
        }
        /// The include file attribute absolute path
        public var absolutePath: String {
            switch self {
                case .file(let rtn): return rtn.absolutePath.string
                case .folder(let rtn): return rtn.absolutePath.string
                case .packageDependency(let rtn): return rtn.url
            }
        }
        
        /// Indicator if the onlyOnce attribute was set
        public var includeOnlyAttributeSet: Bool {
            guard case .file(let f) = self else { return false }
            return f.includeOnlyAttributeSet
        }
        
        /// Indicator if include comment blocks should be visible or not
        public var disableIncludeCommentBlocks: Bool {
            switch self {
                case .file(let rtn): return rtn.disableIncludeCommentBlocks
                case .folder(let rtn): return rtn.disableIncludeCommentBlocks
                case .packageDependency(let rtn): return rtn.disableIncludeCommentBlocks
            }
        }
        
        /// Checks to see if the tag reference has external resources
        /// That has been modified since the given date
        public func hasBeenModified(since date: Date,
                                    using fileManager: FileManager = .default,
                                    console: Console = .null) throws -> Bool {
            switch self {
                case .file(let f):
                    return try f.hasBeenModified(since: date,
                                                 using: fileManager,
                                                 console: console)
                case .folder(let f):
                    return try f.hasBeenModified(since: date,
                                                 using: fileManager,
                                                 console: console)
                case .packageDependency(let p):
                    return try p.hasBeenModified(since: date,
                                                 using: fileManager,
                                                 console: console)
            }
        }
    }
   
    
    case include(Include, tagRange: Range<Int>)
    case reference(Reference, tagRange: Range<Int>)
    
    public init(_ value: Include,
                tagRange: Range<String.Index>,
                in source: String) {
        self = .include(value,
                        tagRange: source.distanceRange(of: tagRange))
    }
    
    public init(_ value: Reference,
                tagRange: Range<String.Index>,
                in source: String) {
        self = .reference(value,
                          tagRange: source.distanceRange(of: tagRange))
    }
    
    public internal(set) var tagRange: Range<Int> {
        get {
            switch self {
                case .include(_, tagRange: let rtn): return rtn
                case .reference(_, tagRange: let rtn): return rtn
            }
        }
        set {
            switch self {
                case .include(let i, tagRange: _):
                    self = .include(i, tagRange: newValue)
                case .reference(let r, tagRange: _):
                    self = .reference(r, tagRange: newValue)
            }
        }
    }
    /// Checks to see if the tag reference has external resources
    /// That has been modified since the given date
    public func hasBeenModified(since date: Date,
                                using fileManager: FileManager = .default,
                                console: Console = .null) throws -> Bool {
        switch self {
            case .reference(let r, tagRange: _):
                return try r.hasBeenModified(since: date,
                                             using: fileManager,
                                             console: console)
            case .include(let i, tagRange: _):
                return try i.hasBeenModified(since: date,
                                             using: fileManager,
                                             console: console)
        }
    }

    public func stringRange(for string: String) -> Range<String.Index> {
        let lowerBound = string.index(offsetBy: self.tagRange.lowerBound)
        let upperBound = string.index(offsetBy: self.tagRange.upperBound)
        return lowerBound..<upperBound
    }
    
    internal mutating func adjustingTagRange(difference: Int) {
        guard difference != 0 else { return }
        
        self.tagRange = (self.tagRange.lowerBound + difference)..<(self.tagRange.upperBound + difference)
    }
}

// MARK: - Tag Parse Properties
public extension DSwiftTag {
    enum TagParsing: Swift.Error, CustomStringConvertible {
        case invalidTagAttributes(tag: String,
                                  attributes: [String],
                                  in: String,
                                  onLine: Int)
        case invalidTagAttributeValue(tag: String,
                                      attribute: String,
                                      value: String,
                                      expecting: [String]?,
                                      in: String,
                                      onLine: Int)
        case invalidTagAttributeRegExValue(tag: String,
                                           attribute: String,
                                           value: String,
                                           error: Error,
                                           in: String,
                                           onLine: Int)
        case missingTagAttributes(tag: String,
                                  attributes: [String],
                                  in: String,
                                  onLine: Int)
        case invalidVersion(tag: String,
                            attribute: String,
                            version: String,
                            in: String,
                            onLine: Int)
        case invalidVersionRange(tag: String,
                                 attribute: String,
                                 range: String,
                                 in: String,
                                 onLine: Int)
        case includedResourceNotFound(include: String,
                                      includeFullPath: String,
                                      in: String,
                                      onLine: Int)
        
        public var description: String {
            switch self {
                case .invalidTagAttributes(tag: let tag,
                                           attributes: let attribs,
                                           in: let path,
                                           onLine: let line):
                    if attribs.count > 1 {
                        return "\(path): Invalid Attributes '\(attribs.map({ return "'\($0)'" }).joined(separator: ", "))' in tag '\(tag)' on line \(line) OR dswift may need to be updated to a newer version"
                    } else {
                        return "\(path): Invalid Attribute '\(attribs.first!)' in tag '\(tag)' on line \(line) OR dswift may need to be updated to a newer version"
                    }
                case .invalidTagAttributeValue(tag: let tag,
                                               attribute: let attrib,
                                               value: let value,
                                               expecting: let expecting,
                                               in: let path,
                                               onLine: let line):
                    
                    var rtn: String = "\(path): Attribute '\(tag)/\(attrib)' has an invalid value '\(value)'"
                    if let exp = expecting {
                        rtn += ". Expecting" + exp.map({ return "'\($0)'" }).joined(separator: " OR ")
                    }
                    rtn += " on line \(line)"
                    return rtn
                case .invalidTagAttributeRegExValue(tag: let tag,
                                                attribute: let attrib,
                                                value: let value,
                                                error: let err,
                                                in: let path,
                                                onLine: let line):
                    return "\(path): Attribute '\(tag)/\(attrib)' has an invalid regular expression value '\(value)' on line \(line): \(err)"
                case .missingTagAttributes(tag: let tag,
                                           attributes: let attribs,
                                           in: let path,
                                           onLine: let line):
                    if attribs.count > 1 {
                        return "\(path): Missing Attributes '\(attribs.map({ return "'\($0)'" }).joined(separator: " OR "))' in tag '\(tag)' on line \(line)"
                    } else {
                        return "\(path): Missing Attribute '\(attribs.first!)' in tag '\(tag)' on line \(line)"
                    }
                case .invalidVersion(tag: let tag,
                                     attribute: let attrib,
                                     version: let ver,
                                     in: let path,
                                     onLine: let line):
                    return "\(path): Invalid Version '\(ver)' in attribute '\(attrib)' on tag '\(tag)' on line \(line)"
                case .invalidVersionRange(tag: let tag,
                                          attribute: let attrib,
                                          range: let range,
                                          in: let path,
                                          onLine: let line):
                return "\(path): Invalid Version Range '\(range)' in attribute '\(attrib)' on tag '\(tag)' on line \(line)"
                case .includedResourceNotFound(include: let include,
                                               includeFullPath: let
                                               includeFullPath,
                                               in: let path,
                                               onLine: let line):
                    return "\(path): Include resource '\(include)' / '\(includeFullPath)' on line \(line) not found"
            }
        }
    }
}

// MARK: - Tag Property Parsers
public extension DSwiftTag.Include.File {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Include.File {
        
        var attributes = attributes
        guard let file = attributes[DSwiftTag.Include.File.identifierAttribute] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [DSwiftTag.Include.File.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        attributes[DSwiftTag.Include.File.identifierAttribute] = nil
        
        var includeOnlyOnce: Bool = false
        var includeOnlyAttributeSet: Bool = false
        var disableIncludeCommentBlocks: Bool = false
        
        if let val = attributes["onlyonce"] {
            attributes["onlyonce"] = nil
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "onlyOnce",
                                                                    value: val,
                                                                    expecting: ["true", 
                                                                                "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            
            includeOnlyOnce = b
            includeOnlyAttributeSet = true
        }
        
        if let val = attributes["quiet"] {
            attributes["quiet"] = nil
            
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "quiet",
                                                                    value: val,
                                                                    expecting: ["true",
                                                                                "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            disableIncludeCommentBlocks = b
        }
        
        guard attributes.isEmpty else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributes(tag: tagName,
                                                            attributes: Array(attributes.keys),
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        
        let includeFileStr = file.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<PROJECT_ROOT>",
                                  with: project.rootPath.string)
            .replacingOccurrences(of: "//", with: "/")
        
        let includeFilePath = FSRelativePath(includeFileStr)
        
        let includeFileFullPath = includeFilePath.fullPath(referencing: path.deletingLastComponent())
        
        
        guard includeFileFullPath.exists(using: fileManager) else {
            // Include file not found
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.includedResourceNotFound(include: includeFileStr,
                                                                includeFullPath: includeFileFullPath.string,
                                                                in: path.string,
                                                                onLine: line + 1)
        }
        
        console.printVerbose("Found include file '\(file)' in '\(path)'", object: self)
        
        return .init(tagName: tagName,
                     //tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                     path: includeFilePath,
                     absolutePath: includeFileFullPath,
                     includeOnlyOnce: includeOnlyOnce,
                     includeOnlyAttributeSet: includeOnlyAttributeSet,
                     disableIncludeCommentBlocks: disableIncludeCommentBlocks)
        
    }
}

public extension DSwiftTag.Include.Folder {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Include.Folder {
        
        var attributes = attributes
        guard let folder = attributes[DSwiftTag.Include.Folder.identifierAttribute] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [DSwiftTag.Include.Folder.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        attributes[DSwiftTag.Include.Folder.identifierAttribute] = nil
        
        var extensionMappings: [FSExtension: FSExtension] = [:]
        var disableIncludeCommentBlocks: Bool = false
        
        var regExFilter: RegEx? = nil
        if let filter = attributes["filter"] {
            attributes["filter"] = nil
            do {
                regExFilter = try RegEx(filter)
            } catch {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                
                throw DSwiftTag.TagParsing.invalidTagAttributeRegExValue(tag: tagName,
                                                                         attribute: "filter",
                                                                         value: filter,
                                                                         error: error,
                                                                         in: path.string,
                                                                         onLine: line + 1)
            }
        }
        
        var includeExtensions: [FSExtension] = []
        if let includes = attributes["includeextensions"] {
            attributes["includeextensions"] = nil
            includeExtensions = includes.split(separator: ",")
                .map(String.init)
                .map { return $0.trimmingCharacters(in: .whitespaces) }
                .map { return FSExtension($0) }
        }
        
        var excludeExtensions: [FSExtension] = []
        if let excludes = attributes["excludeextensions"] {
            attributes["excludeextensions"] = nil
            excludeExtensions = excludes.split(separator: ",")
                .map(String.init)
                .map { return $0.trimmingCharacters(in: .whitespaces) }
                .map { return FSExtension($0) }
        }
        
        if let val = attributes["extensionmapping"] {
            attributes["extensionmapping"] = nil
            
            for mapping in val.split(separator: ";").map(String.init) {
                let components = mapping.split(separator: ":").map(String.init)
                guard components.count == 2 else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    
                    throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                        attribute: "extensionMapping",
                                                                        value: mapping,
                                                                        expecting: ["{extFrom:extTo}"],
                                                                        in: path.string,
                                                                        onLine: line + 1)
                }
                
                extensionMappings[FSExtension(components[0])] = FSExtension(components[1])
            }
        }
        
        if let val = attributes["quiet"] {
            attributes["quiet"] = nil
            
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "quiet",
                                                                    value: val,
                                                                    expecting: ["true", "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            disableIncludeCommentBlocks = b
        }
        
        var propagateAttributes: Bool = true
        if let val = attributes["propagateattributes"] {
            attributes["propagateattributes"] = nil
            
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "propagateAttributes",
                                                                    value: val,
                                                                    expecting: ["true", "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            propagateAttributes = b
        }
        
        guard attributes.isEmpty else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributes(tag: tagName,
                                                            attributes: Array(attributes.keys),
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        let includeFolderStr = folder.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<PROJECT_ROOT>",
                                  with: project.rootPath.string)
            .replacingOccurrences(of: "//", with: "/")
        
        let includeFolderPath = FSRelativePath(includeFolderStr)
        
        let includeFolderFullPath = includeFolderPath.fullPath(referencing: path.deletingLastComponent())
        
        
        guard includeFolderFullPath.exists(using: fileManager) else {
            // Include file not found
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.includedResourceNotFound(include: includeFolderStr,
                                                                includeFullPath: includeFolderFullPath.string,
                                                                in: path.string,
                                                                onLine: line + 1)
        }
        
        console.printVerbose("Found include folder '\(includeFolderPath)' in '\(path)'", object: self)
        
        return .init(tagName: tagName,
                     //tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                     path: includeFolderPath,
                     absolutePath: includeFolderFullPath,
                     includeExtensions: includeExtensions,
                     excludeExtensions: excludeExtensions,
                     extensionMapping: extensionMappings,
                     filter: regExFilter,
                     propagateAttributes: propagateAttributes,
                     disableIncludeCommentBlocks: disableIncludeCommentBlocks,
                     childFolders: [])
        
    }
}

public extension DSwiftTag.Include.GitPackageDependency {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Include.GitPackageDependency {
        
        var attributes = attributes
        guard let package = attributes[DSwiftTag.Include.GitPackageDependency.identifierAttribute] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [DSwiftTag.Include.GitPackageDependency.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        attributes[DSwiftTag.Include.GitPackageDependency.identifierAttribute] = nil
        
        guard URL(string: package) != nil else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                attribute: DSwiftTag.Include.GitPackageDependency.identifierAttribute,
                                                                value: package,
                                                                expecting: nil,
                                                                in: path.string,
                                                                onLine: line + 1)
        }
        
        let req: DSwiftTag.Include.GitPackageDependency.Requirements
        
        if let from = attributes["from"] {
            attributes["from"] = nil
            guard let ver = Version.SingleVersion(from) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                          attribute: "from",
                                                          version: from,
                                                          in: path.string,
                                                          onLine: line + 1)
            }
            req = .from(ver)
            
        } else if let range = attributes["range"] {
            attributes["range"] = nil
            if let splitRange = range.range(of: "..<") {
                let strLower = String(range[..<splitRange.lowerBound])
                let strUpper = String(range[splitRange.upperBound...])
                
                guard let lowerVersion = Version.SingleVersion(strLower) else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strLower,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                
                guard let upperVersion = Version.SingleVersion(strUpper) else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strUpper,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                guard lowerVersion < upperVersion else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strLower,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                req = .range(lowerBound: lowerVersion, upperBound: upperVersion)
            } else if let splitRange = range.range(of: "...") {
                let strLower = String(range[..<splitRange.lowerBound])
                let strUpper = String(range[splitRange.upperBound...])
                
                guard let lowerVersion = Version.SingleVersion(strLower) else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strLower,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                
                guard let upperVersion = Version.SingleVersion(strUpper) else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strUpper,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                guard lowerVersion < upperVersion else {
                    let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                    throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                              attribute: "range",
                                                              version: strLower,
                                                              in: path.string,
                                                              onLine: line + 1)
                }
                req = .closedRange(lowerBound: lowerVersion, upperBound: upperVersion)
            } else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidVersionRange(tag: tagName,
                                                               attribute: "range",
                                                               range: range,
                                                               in: path.string,
                                                               onLine: line + 1)
            }
            
        } else if let exact =  attributes["exact"] {
            attributes["exact"] = nil
            guard let ver = Version.SingleVersion(exact) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidVersion(tag: tagName,
                                                          attribute: "exact",
                                                          version: exact,
                                                          in: path.string,
                                                          onLine: line + 1)
            }
            req = .exact(ver)
        } else if let branch =  attributes["branch"] {
            attributes["branch"] = nil
            req = .branch(branch)
        } else if let revision =  attributes["revision"] {
            attributes["revision"] = nil
            req = .revision(revision)
        } else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [
                                                                         "from",
                                                                         "range",
                                                                         "exact",
                                                                         "branch",
                                                                         "revision"
                                                                        ],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        guard let strPackageNames = attributes["packagenames"] ?? attributes["packagename"] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: ["packageNames",
                                                                         "packageName"],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
       
        attributes["packagenames"] = nil
        attributes["packagename"] = nil
        
        let packageNames = strPackageNames.split(separator: ",")
            .map(String.init)
            .map { return $0.trim() }
        
        var disableIncludeCommentBlocks: Bool = false
        
        if let val = attributes["quiet"] {
            attributes["quiet"] = nil
            
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "quiet",
                                                                    value: val,
                                                                    expecting: ["true",
                                                                                "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            disableIncludeCommentBlocks = b
        }
        
        guard attributes.isEmpty else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributes(tag: tagName,
                                                            attributes: Array(attributes.keys),
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        console.printVerbose("Found include package '\(package)': \(req.displayDetails) in '\(path)'", object: self)
        
        return .init(tagName: tagName,
                     //tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                     url: package,
                     requirements: req,
                     packageNames: packageNames,
                     disableIncludeCommentBlocks: disableIncludeCommentBlocks)
    }
}

public extension DSwiftTag.Include {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Include {
        
        if File.isFileTag(attributes) {
            return .file(try File.parseProperties(tagName: tagName,
                                                  attributes: attributes,
                                                  source: source,
                                                  path: path,
                                                  tagRange: tagRange,
                                                  project: project,
                                                  console: console,
                                                  using: fileManager))
        } else if Folder.isFileTag(attributes) {
            return .folder(try Folder.parseProperties(tagName: tagName,
                                                      attributes: attributes,
                                                      source: source,
                                                      path: path,
                                                      tagRange: tagRange,
                                                      project: project,
                                                      console: console,
                                                      using: fileManager))
        } else if GitPackageDependency.isFileTag(attributes) {
            return .packageDependency(try GitPackageDependency.parseProperties(tagName: tagName,
                                                                               attributes: attributes,
                                                                               source: source,
                                                                               path: path,
                                                                               tagRange: tagRange,
                                                                               project: project,
                                                                               console: console,
                                                                               using: fileManager))
        } else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [File.identifierAttribute,
                                                                         Folder.identifierAttribute,
                                                                         GitPackageDependency.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
    }
}


public extension DSwiftTag.Reference.File {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Reference.File {
        
        var attributes = attributes
        guard let file = attributes[DSwiftTag.Reference.File.identifierAttribute] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [DSwiftTag.Reference.File.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        attributes[DSwiftTag.Reference.File.identifierAttribute] = nil
        
        guard attributes.isEmpty else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributes(tag: tagName,
                                                                attributes: Array(attributes.keys),
                                                                in: path.string,
                                                                onLine: line + 1)
        }
        
        
        
        let includeFileStr = file.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<PROJECT_ROOT>",
                                  with: project.rootPath.string)
            .replacingOccurrences(of: "//", with: "/")
        
        let includeFilePath = FSRelativePath(includeFileStr)
        
        let includeFileFullPath = includeFilePath.fullPath(referencing: path.deletingLastComponent())
        
        return .init(tagName: tagName,
                     //tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                     path: includeFilePath,
                     absolutePath: includeFileFullPath)
        
    }
}

public extension DSwiftTag.Reference.Folder {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Reference.Folder {
        
        var attributes = attributes
        guard let folder = attributes[DSwiftTag.Reference.Folder.identifierAttribute] else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [DSwiftTag.Reference.Folder.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        
        attributes[DSwiftTag.Reference.Folder.identifierAttribute] = nil
        
        var regExFilter: RegEx? = nil
        if let filter = attributes["filter"] {
            attributes["filter"] = nil
            do {
                regExFilter = try RegEx(filter)
            } catch {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                
                throw DSwiftTag.TagParsing.invalidTagAttributeRegExValue(tag: tagName,
                                                                         attribute: "filter",
                                                                         value: filter,
                                                                         error: error,
                                                                         in: path.string,
                                                                         onLine: line + 1)
            }
        }
        
        var includeExtensions: [FSExtension] = []
        if let includes = attributes["includeextensions"] {
            attributes["includeextensions"] = nil
            includeExtensions = includes.split(separator: ",")
                .map(String.init)
                .map { return $0.trimmingCharacters(in: .whitespaces) }
                .map { return FSExtension($0) }
        }
        
        var excludeExtensions: [FSExtension] = []
        if let excludes = attributes["excludeextensions"] {
            attributes["excludeextensions"] = nil
            excludeExtensions = excludes.split(separator: ",")
                .map(String.init)
                .map { return $0.trimmingCharacters(in: .whitespaces) }
                .map { return FSExtension($0) }
        }
        
        
        var propagateAttributes: Bool = true
        if let val = attributes["propagateAttributes"] {
            attributes["propagateAttributes"] = nil
            
            guard let b = Bool(val) else {
                let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
                throw DSwiftTag.TagParsing.invalidTagAttributeValue(tag: tagName,
                                                                    attribute: "propagateAttributes",
                                                                    value: val,
                                                                    expecting: ["true",
                                                                                "false"],
                                                                    in: path.string,
                                                                    onLine: line + 1)
            }
            propagateAttributes = b
        }
        
        guard attributes.isEmpty else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.invalidTagAttributes(tag: tagName,
                                                            attributes: Array(attributes.keys),
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
        let includeFolderStr = folder.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "<PROJECT_ROOT>",
                                  with: project.rootPath.string)
            .replacingOccurrences(of: "//", with: "/")
        
        let includeFolderPath = FSRelativePath(includeFolderStr)
        
        let includeFolderFullPath = includeFolderPath.fullPath(referencing: path.deletingLastComponent())
        
        guard includeFolderFullPath.exists(using: fileManager) else {
            // Include file not found
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            throw DSwiftTag.TagParsing.includedResourceNotFound(include: includeFolderStr,
                                                                includeFullPath: includeFolderFullPath.string,
                                                                in: path.string,
                                                                onLine: line + 1)
        }
        
        return .init(tagName: tagName,
                     //tagRange: startTagRange.lowerBound..<endTagRange.upperBound,
                     path: includeFolderPath,
                     absolutePath: includeFolderFullPath,
                     includeExtensions: includeExtensions,
                     excludeExtensions: excludeExtensions,
                     filter: regExFilter,
                     propagateAttributes: propagateAttributes,
                     childFolders: [])
        
    }
}

public extension DSwiftTag.Reference {
    static func parseProperties(tagName: String,
                                attributes: [String: String],
                                source: String,
                                path: FSPath,
                                tagRange: Range<String.Index>,
                                project: SwiftProject,
                                console: Console = .null,
                                using fileManager: FileManager) throws -> DSwiftTag.Reference {
        
        if File.isFileTag(attributes) {
            return .file(try File.parseProperties(tagName: tagName,
                                                  attributes: attributes,
                                                  source: source,
                                                  path: path,
                                                  tagRange: tagRange,
                                                  project: project,
                                                  console: console,
                                                  using: fileManager))
        } else if Folder.isFileTag(attributes) {
            return .folder(try Folder.parseProperties(tagName: tagName,
                                                      attributes: attributes,
                                                      source: source,
                                                      path: path,
                                                      tagRange: tagRange,
                                                      project: project,
                                                      console: console,
                                                      using: fileManager))
        } else {
            let line = source.countOccurrences(of: "\n", before: tagRange.lowerBound)
            
            throw DSwiftTag.TagParsing.missingTagAttributes(tag: tagName,
                                                            attributes: [File.identifierAttribute,
                                                                         Folder.identifierAttribute],
                                                            in: path.string,
                                                            onLine: line + 1)
        }
        
    }
}

// MARK: - Verify file Tools Version
public extension DSwiftTag {
    enum VerifyToolsVersionError: Swift.Error {
        case minimumDSwiftToolsVersionNotMet(for: String,
                                                expected: String,
                                                found: String,
                                                description: String?)
        
        public var description: String {
            switch self {
                case .minimumDSwiftToolsVersionNotMet(for: let path,
                                                     expected: let expected,
                                                     found: let found,
                                                     description: let desc):
                    var rtn = "\(path): Minimum dswift-tools-version '\(expected)' not met.  Current version is '\(found)'"
                    if let d = desc { rtn += ". " + d }
                    return rtn
            }
        }
    }
}
public extension DSwiftTag.Reference.File {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        
    }
}

public extension DSwiftTag.Reference.Folder {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        
    }
}

public extension DSwiftTag.Reference {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        guard version >= self.minimumSupportedTagVersion else {
            throw DSwiftTag.VerifyToolsVersionError.minimumDSwiftToolsVersionNotMet(for: path.string,
                                                         expected: self.minimumSupportedTagVersion.description,
                                                         found: version.description,
                                                                             description: "Tag \(self.tagName) requires a minimum version of '\(self.minimumSupportedTagVersion)'")
        }
        switch self {
            case .file(let f):
                try f.verifyDSwiftToolsVersion(version,
                                               for: path)
            case .folder(let f):
                try f.verifyDSwiftToolsVersion(version,
                                               for: path)
        }
    }
}

public extension DSwiftTag.Include.File {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        
    }
}

public extension DSwiftTag.Include.Folder {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        guard version >= self.minimumSupportedTagVersion else {
            throw DSwiftTag.VerifyToolsVersionError.minimumDSwiftToolsVersionNotMet(for: path.string,
                                                         expected: self.minimumSupportedTagVersion.description,
                                                         found: version.description,
                                                                             description: "Tag \(self.tagName)[folder] requires a minimum version of '\(self.minimumSupportedTagVersion)'")
        }
    }
}

public extension DSwiftTag.Include.GitPackageDependency {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        guard version >= self.minimumSupportedTagVersion else {
            throw DSwiftTag.VerifyToolsVersionError.minimumDSwiftToolsVersionNotMet(for: path.string,
                                                         expected: self.minimumSupportedTagVersion.description,
                                                         found: version.description,
                                                                             description: "Tag \(self.tagName)[package] requires a minimum version of '\(self.minimumSupportedTagVersion)'")
        }
    }
}


public extension DSwiftTag.Include {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        guard version >= self.minimumSupportedTagVersion else {
            throw DSwiftTag.VerifyToolsVersionError.minimumDSwiftToolsVersionNotMet(for: path.string,
                                                         expected: self.minimumSupportedTagVersion.description,
                                                         found: version.description,
                                                                             description: "Tag \(self.tagName) requires a minimum version of '\(self.minimumSupportedTagVersion)'")
        }
        switch self {
            case .file(let f):
                try f.verifyDSwiftToolsVersion(version,
                                               for: path)
            case .folder(let f):
                try f.verifyDSwiftToolsVersion(version,
                                               for: path)
            case .packageDependency(let g):
                try g.verifyDSwiftToolsVersion(version,
                                               for: path)
        }
    }
}

public extension DSwiftTag {
    func verifyDSwiftToolsVersion(_ version: Version.SingleVersion,
                                  for path: FSPath) throws {
        switch self {
            case .reference(let r, tagRange: _):
                try r.verifyDSwiftToolsVersion(version,
                                               for: path)
            case .include(let i, tagRange: _):
                try i.verifyDSwiftToolsVersion(version,
                                               for: path)
        }
    }
}

public extension DSwiftTag {
    
    struct ReplacementDetails {
        //var externalReferences: ExternalReferences
        //var includeSources: [String: String]
        var includeFolders: [DSwiftTag.Include.Folder]
        var includePackages: [DSwiftTag.Include.GitPackageDependency]
        var content: String
        
        public init(//externalReferences: ExternalReferences = .init(),
                    //includeSources: [String: String] = [:],
                    includeFolders: [DSwiftTag.Include.Folder] = [],
                    includePackages: [DSwiftTag.Include.GitPackageDependency] = [],
                    content: String = "") {
            self.content = content
            //self.externalReferences = externalReferences
            //self.includeSources = includeSources
            self.includeFolders = includeFolders
            self.includePackages = includePackages
            
        }
        
        public init(_ processedTags: DynamicSourceCodeBuilder.ProcessedTags) {
            self.init(includeFolders: processedTags.includeFolders,
                      includePackages: processedTags.includePackages,
                      content: processedTags.source)
        }
        
        public mutating func append(_ folders: [DSwiftTag.Include.Folder]) {
            // Include child include folders into our include folder root
            var tempRoot = DSwiftTag.Include.Folder.root(currentChildren:  self.includeFolders)
            tempRoot.appendChildFolders(folders)
            self.includeFolders = tempRoot.childFolders
        }
        
        public mutating func append(_ folder: DSwiftTag.Include.Folder) {
            self.append([folder])
        }
        
        
        
        public mutating func append(_ dependencies: [DSwiftTag.Include.GitPackageDependency]) {
            // Include child include folders into our include folder root
            for includePackage in dependencies {
                if !self.includePackages.contains(where: { return $0.url == includePackage.url }) {
                    self.includePackages.append(includePackage)
                }
            }
        }
        
        
        public mutating func append(_ dependency: DSwiftTag.Include.GitPackageDependency) {
            self.append([dependency])
        }
        
        public mutating func append(_ processed: ReplacementDetails, filePath: String) {
            // Include child include folders into our include folder root
            self.append(self.includeFolders)
            
            // Include child include packages into our include package list
            self.append(processed.includePackages)
        }
        
        public mutating func append(_ folder: DSwiftTag.Include.Folder, for path: String) {
            self.append(folder)
        }
    }
    
}

// MARK: - Tag Replacement Text
public extension DSwiftTag.Reference.File {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        return DSwiftTag.ReplacementDetails(content: """
/* *** \(self.tagName)[file] Begin ***
\(preTagWhiteSpacing)*     Path: "\(self.path)"
\(preTagWhiteSpacing)*** \(self.tagName)[file] End *** */
""")
    }
}
public extension DSwiftTag.Reference.Folder {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        return DSwiftTag.ReplacementDetails(content: """
/* *** \(self.tagName)[folder] Begin ***
\(preTagWhiteSpacing)*     Path: \(self.path)
\(preTagWhiteSpacing)*     Filter: \(self.filter?.pattern.encapsulate("\"") ?? "nil")
\(preTagWhiteSpacing)*     Include Extensions: \(self.includeExtensions.expressAsSingleLineString())
\(preTagWhiteSpacing)*     Exclude Extensions: \(self.excludeExtensions.expressAsSingleLineString())
\(preTagWhiteSpacing)*     Propagate Attributes: \(self.propagateAttributes)
\(preTagWhiteSpacing)*** \(self.tagName)[folder] End *** */
""")
    }
}
public extension DSwiftTag.Reference {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        switch self {
            case .file(let f):
            return try f.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                            tagReplacementDetails: tagReplacementDetails,
                                            project: project,
                                            dswiftInfo: dswiftInfo,
                                            preloadedDetails: preloadedDetails,
                                                console: console,
                                            using: fileManager)
            case .folder(let f):
                return try f.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
        }
    }
}
public extension DSwiftTag.Include.File {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        
        let alreadyIncluded = tagReplacementDetails.includeReplacement.processedIncludeFiles.contains(self.absolutePath.string)
        
        guard !(self.includeOnlyOnce && alreadyIncluded) else {
            guard !self.disableIncludeCommentBlocks else {
                return DSwiftTag.ReplacementDetails(content: "")
            }
            
            return DSwiftTag.ReplacementDetails(content: """
            /* *** \(self.tagName)[file] '\(self.path)' Begin *** */
            /* *** State: Already included elsewhere *** */
            /* *** \(self.tagName)[file] '\(self.path)' End *** */
            """)

        }
        
        
        
        let content = try DynamicSourceCodeBuilder.processDSwiftTags(from: self.absolutePath,
                                                                     tagReplacementDetails: tagReplacementDetails,
                                                                     project: project,
                                                                     dswiftInfo: dswiftInfo,
                                                                     preloadedDetails: preloadedDetails,
                                                                     console: console,
                                                                     using: fileManager)
        
        //print("**** Include \(self.path) Begin ****\n" + content.source + "\n**** Include \(self.path) End ****\n" )
        if !alreadyIncluded {
            tagReplacementDetails
                .includeReplacement
                .processedIncludeFiles
                .append(self.absolutePath.string)
        }
        
        
        
        var rtn = DSwiftTag.ReplacementDetails(content)
        if !self.disableIncludeCommentBlocks {
            rtn.content = rtn.content.encapsulate(prefix: "/* *** \(self.tagName)[file] '\(self.path)' Begin *** */\n",
                                                  suffix: "\n\(preTagWhiteSpacing)/* *** \(self.tagName)[file] '\(self.path)' End *** */")
        }
        
        return rtn
    }
}
public extension DSwiftTag.Include.Folder {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        return DSwiftTag.ReplacementDetails(includeFolders: [self],
                                            content: """
/* *** \(self.tagName)[folder] Begin ***
\(preTagWhiteSpacing)*     Path: "\(self.path)"
\(preTagWhiteSpacing)*     Filter: \(self.filter?.pattern.encapsulate("\"") ?? "nil")
\(preTagWhiteSpacing)*     Include Extensions: \(self.includeExtensions.expressAsSingleLineString())
\(preTagWhiteSpacing)*     Exclude Extensions: \(self.excludeExtensions.expressAsSingleLineString())
\(preTagWhiteSpacing)*     Extension Mapping: \(self.extensionMapping.expressAsSingleLineString())
\(preTagWhiteSpacing)*     Propagate Attributes: \(self.propagateAttributes)
\(preTagWhiteSpacing)*** \(self.tagName)[folder] End *** */
""")
    }
}
public extension DSwiftTag.Include.GitPackageDependency {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        return DSwiftTag.ReplacementDetails(includePackages: [self],
                                            content: """
/* *** \(self.tagName)[package] Begin ***
\(preTagWhiteSpacing)*     URL: "\(self.url)"
\(preTagWhiteSpacing)*     \(self.requirements.displayDetails)"
\(preTagWhiteSpacing)*     Package Names: \(self.packageNames.expressAsSingleLineString())
\(preTagWhiteSpacing)*** \(self.tagName)[package] End *** */
""")
    }
}
public extension DSwiftTag.Include {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> DSwiftTag.ReplacementDetails {
        switch self {
            case .file(let f):
                return try f.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
            case .folder(let f):
                return try f.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
            case .packageDependency(let p):
                return try p.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
            
        }
    }
}
public extension DSwiftTag {
    func replaceTagTextWith(preTagWhiteSpacing: String,
                            tagReplacementDetails: DynamicSourceCodeGenerator.TagReplacementDetails,
                            project: SwiftProject,
                            dswiftInfo: DSwiftInfo,
                            preloadedDetails: DynamicSourceCodeGenerator.PreloadedDetails,
                            console: Console = .null,
                            using fileManager: FileManager) throws -> ReplacementDetails {
        switch self {
            case .reference(let r, tagRange: _):
                return try r.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
            case .include(let i, tagRange: _):
                return try i.replaceTagTextWith(preTagWhiteSpacing: preTagWhiteSpacing,
                                                tagReplacementDetails: tagReplacementDetails,
                                                project: project,
                                                dswiftInfo: dswiftInfo,
                                                preloadedDetails: preloadedDetails,
                                                console: console,
                                                using: fileManager)
        }
    }
}

internal extension DSwiftTag {
    func tagString(from string: String) -> String {
        let lowerBound = string.index(offsetBy: self.tagRange.lowerBound)
        let upperBound = string.index(offsetBy: self.tagRange.upperBound)
        
        return String(string[lowerBound..<upperBound])
    }
}
