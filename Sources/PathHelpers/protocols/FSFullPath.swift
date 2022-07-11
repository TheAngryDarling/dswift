//
//  FSFullPath.swift
//  
//
//  Created by Tyler Anger on 2022-04-25.
//

import Foundation

public protocol FSFullPath: FSPathObject {
    
    //init<Path>(_ path: Path) where Path: FSPathObject
    
    //init<Base>(_ path: String, relativeTo base: Base) where Base: FSFullPath
    
    static func +<RHS>(lhs: Self, rhs: RHS) -> Self where RHS: FSRelativePathObject
}

public extension FSFullPath {
    
    static var tempDir: Self {
        return .init(NSTemporaryDirectory())
    }
    
    static var root: Self {
        #if os(Windows)
        return .init("C:\\")
        #else
        return .init("/")
        #endif
    }
}

public extension FSFullPath {
    
    static func +<RHS>(lhs: Self, rhs: RHS) -> Self where RHS: FSRelativePathObject {
        return lhs.appendingComponent(rhs.string)
    }
    
}

// MARK: - Properties
public extension FSFullPath {
    
    /// A new FSPath Object made by expanding the initial component of the receiver to its full path value.
    var expandingTilde: Self {
        return Self.init(NSString(string: self.string).expandingTildeInPath,
                         relativeTo: nil)
    }
    
    /// A new FSPath Object made from the receiver by resolving all symbolic links and standardizing path.
    var resolvingSymlinks: Self {
        return Self.init(self.url.resolvingSymlinksInPath().path,
                         relativeTo: nil)
    }
    
    /// A new FSPath Object made by removing extraneous path components from the receiver.
    var standardizingPath: Self {
        return Self.init(NSString(string: self.string).standardizingPath,
                         relativeTo: nil)
    }
    
    /// Returns a URL of the absolte path of the FSPath object
    var url: URL {
        return URL(fileURLWithPath: self.string)
    }
    
}
 
// MARK: - Methods
public extension FSFullPath {
    /// Returns true if a file system objects exists at the given path
    func exists(using fileManager: FileManager = .default) -> Bool {
        return fileManager.fileExists(atPath: self.string)
    }
    
    /// Returns if current path exists is a directory
    /// Returns nil if does not exists, otherwise will return a bool value if its a directory or not
    func existsAndIsDirectory(using fileManager: FileManager = .default) -> Bool? {
        var isDir: Bool = false
        guard fileManager.fileExists(atPath: self.string,
                                     isDirectory: &isDir) else {
            return nil
        }
        return isDir
        
    }
    /// Returns if current path is a directory
    /// Will returns true only if the path exists and is a directory
    func isDirectory(using fileManager: FileManager = .default) -> Bool {
        guard let rtn = self.existsAndIsDirectory(using: fileManager) else {
            return false
        }
        return rtn
    }
    
    /// Returns if current path exists is a file
    /// Returns nil if does not exists, otherwise will return a bool value if its a file or not
    func existsAndIsFile(using fileManager: FileManager = .default) -> Bool? {
        guard let rtn = self.existsAndIsDirectory(using: fileManager) else {
            return nil
        }
        return !rtn
        
    }
    
    /// Returns if the current path is a file
    /// Returns true only if the path exists and is a file
    func isFile(using fileManager: FileManager = .default) -> Bool {
        guard let rtn = self.existsAndIsFile(using: fileManager) else {
            return false
        }
        return rtn
    }
    
    /// Returns a Boolean value that indicates whether the invoking object appears able to read a specified file.
    func isReadableFile(using fileManager: FileManager = .default) -> Bool {
        return fileManager.isReadableFile(atPath: self.string)
    }
    /// Returns a Boolean value that indicates whether the invoking object appears able to write to a specified file.
    func isWritableFile(using fileManager: FileManager = .default) -> Bool {
        return fileManager.isWritableFile(atPath: self.string)
    }
    /// Returns a Boolean value that indicates whether the operating system appears able to execute a specified file.
    func isExecutableFile(using fileManager: FileManager = .default) -> Bool {
        return fileManager.isExecutableFile(atPath: self.string)
    }
    /// Returns a Boolean value that indicates whether the invoking object appears able to delete a specified file.
    func isDeletableFile(using fileManager: FileManager = .default) -> Bool {
        return fileManager.isDeletableFile(atPath: self.string)
    }
    
    /// Returns the contents of the file at the specified path.
    func contents(using fileManager: FileManager = .default) -> Data? {
        return fileManager.contents(atPath: self.string)
    }
    
    /// Returns a Boolean value that indicates whether the files or directories in specified paths have the same contents.
    func contentsEqual<Path>(_ path2: Path,
                             using fileManager: FileManager = .default) -> Bool where Path: FSFullPath {
        return fileManager.contentsEqual(atPath: self.string,
                                         andPath: path2.string)
    }
    
    /// Indicator if this object is a child of the provided path
    func isChildPath<Path>(of path: Path) -> Bool where Path: FSFullPath {
        let childPath = self.string
        var parentPath = path.string
        if !parentPath.hasSuffix(self.componentSeparatorStr) {
            parentPath += self.componentSeparatorStr
        }
        
        return childPath.hasPrefix(parentPath)
    }
    /// Indicator if this object is the parent of the provided path
    func isParentPath<Path>(of path: Path) -> Bool where Path: FSFullPath {
        let childPath = path.string
        var parentPath = self.string
        if !parentPath.hasSuffix(self.componentSeparatorStr) {
            parentPath += self.componentSeparatorStr
        }
        
        return childPath.hasPrefix(parentPath)
    }
    
    func relative<Path>(to path: Path) -> FSRelativePath? where Path: FSFullPath {
        var childPath = self.string
        var parentPath = path.string
        if !parentPath.hasSuffix(self.componentSeparatorStr) {
            parentPath += self.componentSeparatorStr
        }
        guard childPath.hasPrefix(parentPath) else {
            return nil
        }
        
        childPath.removeFirst(parentPath.count)
        
        return FSRelativePath(childPath)
    }
    
    func relativePathOnly<Path>(to path: Path) -> Self? where Path: FSFullPath {
        
        guard let rel = relative(to: path) else {
            return nil
        }
        
        return .init(rel.string)
    }
    
    func relativePath<Path>(to path: Path) -> Self where Path: FSFullPath {
        return self.relativePathOnly(to: path) ?? self
    }
}
