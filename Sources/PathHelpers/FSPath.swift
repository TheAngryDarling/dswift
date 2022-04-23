//
//  FSPath.swift
//  PathHelpers
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation
import SwiftPatches

public protocol FSPathObject {
    /// The character used to seperate each path component
    static var ComponentSeperator: Character { get }
    /// The character uesd to seperate each path from a list of paths
    static var PathSeperator: Character { get }
    /// The File System Path
    var path: String { get }
    /// The base path for this path
    ///
    /// If this path is absolute then this will be nil
    var basePath: Self? { get }
    
    /// Create new FSPath Object with an absolute path
    init(_ path: String)
    /// Create new FSPath Object
    init(_ path: String, relativeTo base: Self?)
    /// Create new FSPath Object with the given components
    init(_ components: [String])
}

public extension FSPathObject {
    init(_ path: String) {
        self.init(path, relativeTo: nil)
    }
    init(_ components: [String]) {
        self.init(components.joined(separator: "\(FSPath.ComponentSeperator)"),
                  relativeTo: nil)
    }
}

public extension FSPathObject {
    /// Gets the path components of the given string
    var components: [String] {
        return self.path.split(separator: FSPath.ComponentSeperator).map(String.init)
    }

    /// The absolue Path
    ///
    /// If the Path is itself absolute, this will return self.
    var absoluePath: Self {
        guard let b = self.basePath else {
            return self
        }
        var components = b.components
        components.append(contentsOf: self.components)
        
        return Self.init(components)
        
    }
    /// The absolute string for the Path.
    var absolueString: String {
        return self.absoluePath.path
    }
    
    /// Gets the last path component of the given string
    var lastComponent: String {
        return self.components.last ?? ""
    }
    
    /// Deletes the last path component of the given string
    func deletingLastComponent() -> FSPath {
        var comps = self.components
        if comps.count > 0 {
            comps.removeLast()
        }
        var startValue = comps.removeFirst()
        if comps.count > 0 && startValue == "/" { startValue = "" }
        let rtn: String = comps.reduce(startValue) { return $0 + "/" + $1 }
        return .init(rtn)
    }
    
    func appendingComponent(_ component: String) -> Self {
        var comps = self.components
        comps.append(component)
        return .init(comps)
    }
    
    /// Gets the path extension of the given string
    var `extension`: String {
        let file = self.lastComponent
        guard let r = file.range(of: ".", options: .backwards) else {
            return ""
        }
        return String(file[r.upperBound...])
    }
    
    /// Deletes the path extension of the given string
    func deletingExtension() -> FSPath {
        
        var comps = self.components
        if comps.count > 0 {
            if let last = comps.last,
               let r = last.range(of: ".", options: .backwards) {
                comps[comps.count - 1] = String(last[r.upperBound...])
            }
        }
        
        return .init(comps)
    }
    /// Returns true if a file system objects exists at the given path
    func exists(fileManager: FileManager = .default) -> Bool {
        return fileManager.fileExists(atPath: self.path)
    }
    /// Returns if current path is a directory
    /// Will returns true only if the path exists and is a directory
    func isDirectory(fileManager: FileManager = .default) -> Bool {
        var isDir: Bool = false
        guard fileManager.fileExists(atPath: self.path,
                                     isDirectory: &isDir) else {
            return false
        }
        return isDir
    }
    /// Returns if the current path is a file
    /// Returns true only if the path exists and is a file
    func isFile(fileManager: FileManager = .default) -> Bool {
        var isDir: Bool = false
        guard fileManager.fileExists(atPath: self.path,
                                     isDirectory: &isDir) else {
            return false
        }
        return !isDir
    }
}


/// Structure representing a File System Path
public struct FSPath: FSPathObject {
    #if os(Windows)
    public static let ComponentSeperator: Character = "\\"
    public static let PathSeperator: Character = ";"
    #else
    public static let ComponentSeperator: Character = "/"
    public static let PathSeperator: Character = ":"
    #endif
    
    public let path: String
    
    private let _basePath: Any?
    public var basePath: FSPath? { return self._basePath as? FSPath}
    
    /// A helper property that switches from throwing methods to non throwable methods
    public var safely: FSSafePath { return FSSafePath(self) }
    
    public init(_ path: String, relativeTo base: FSPath?) {
        self.path = path
        self._basePath = base
    }
    /// Returns the path modification date if available
    public func modificationDate(fileManager: FileManager = .default) throws -> Date? {
        let attr = try fileManager.attributesOfItem(atPath: self.path)
        return attr[FileAttributeKey.modificationDate] as? Date
    }
    /// Returns the path creation date if available
    public func creationDate(fileManager: FileManager = .default) throws -> Date? {
        let attr = try fileManager.attributesOfItem(atPath: self.path)
        return attr[FileAttributeKey.creationDate] as? Date
    }
}

/// Structure representing a File System Path
/// That will return nil instead of throwing errors
/// if any occurs
public struct FSSafePath: FSPathObject {
    #if os(Windows)
    public static let ComponentSeperator: Character = "\\"
    public static let PathSeperator: Character = ";"
    #else
    public static let ComponentSeperator: Character = "/"
    public static let PathSeperator: Character = ":"
    #endif
    
    public let path: String
    
    private let _basePath: Any?
    public var basePath: FSSafePath? { return self._basePath as? FSSafePath}
    
    public init(_ path: String, relativeTo base: FSSafePath?) {
        self.path = path
        self._basePath = base
    }
    
    fileprivate init(_ path: FSPath) {
        self.path = path.path
        if let bP = path.basePath {
            self._basePath = FSSafePath(bP)
        } else {
            self._basePath = nil
        }
    }
    
    /// Returns the path modification date if available
    public func modificationDate(fileManager: FileManager = .default) -> Date? {
        guard let attr = try? fileManager.attributesOfItem(atPath: self.path) else {
            return nil
        }
        return attr[FileAttributeKey.modificationDate] as? Date
    }
    /// Returns the path creation date if available
    public func creationDate(fileManager: FileManager = .default) throws -> Date? {
        guard let attr = try? fileManager.attributesOfItem(atPath: self.path) else {
            return nil
        }
        return attr[FileAttributeKey.creationDate] as? Date
    }
}


