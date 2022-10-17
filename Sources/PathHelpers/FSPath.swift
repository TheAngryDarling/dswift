//
//  FSPath.swift
//  PathHelpers
//
//  Created by Tyler Anger on 2022-03-22.
//

import Foundation


/// Structure representing a File System Path
public struct FSPath: FSFullPath {
    
    public fileprivate(set) var string: String
    
    /// A helper property that switches from throwing methods to non throwable methods
    public var safely: FSSafePath { return FSSafePath(self) }
    
    private let _basePath: Any?
    public var basePath: FSPath? { return self._basePath as? FSPath }
    
    public init(_ path: String, relativeTo base: FSPath?) {
        
        self.string = FSPath.fullPath(for: path, with: base)
        self._basePath = base
    }
    
    public init<Path>(_ path: Path) where Path: FSPathObject {
        self.string = path.string
        if let bP = path.basePath {
            self._basePath = FSPath(bP)
        } else {
            self._basePath = nil
        }
    }
    
    
}

public extension FSPath {
    mutating func deleteLastComponent() {
        
        let url = self.url.deletingLastPathComponent()
        
        self.string = url.path
    }
    mutating func deleteExtension() {
        /// search range of "."
        var range = self.string.startIndex..<self.string.endIndex
        // find the last component separator
        if let r = self.string.range(of: self.componentSeparatorStr, options: .backwards) {
            range = r.upperBound..<self.string.endIndex
        }
        
        // Find where the "." in the string within the given range
        guard let r = self.string.range(of: ".", options: .backwards, range: range) else {
            return
        }
        /// only copy from start of string upto but not included last "."
        self.string = String(self.string[..<r.lowerBound])
    }
    mutating func appendComponent(_ component: String) {
        guard !component.isEmpty else {
            return
        }
        let workingString = self.string
        var workingComponent = component
        
        if workingComponent.hasPrefix(self.componentSeparatorStr) {
            workingComponent.removeFirst()
        }
        
        self.string = workingString + self.componentSeparatorStr + workingComponent
    }
    
    mutating func appendExtension(_ ext: String) {
        guard !ext.isEmpty else { return }
        self.string += ".\(ext)"
    }
}

public extension FSPath {
    /// Returns the path modification date if available
    func modificationDate(using fileManager: FileManager = .default) throws -> Date? {
        let attr = try fileManager.attributesOfItem(atPath: self.string)
        return attr[FileAttributeKey.modificationDate] as? Date
    }
    /// Returns the path creation date if available
    func creationDate(using fileManager: FileManager = .default) throws -> Date? {
        let attr = try fileManager.attributesOfItem(atPath: self.string)
        return attr[FileAttributeKey.creationDate] as? Date
    }
    
    func setPosixPermissions(_ permission: UInt,
                             using fileManager: FileManager) throws {
        
        try fileManager.setAttributes([.posixPermissions: NSNumber(value: permission)],
                                      ofItemAtPath: self.string)
        
    }
    
    /// Copies the item at the specified path to a new location synchronously.
    func copy<Path>(to path: Path,
                    using fileManager: FileManager = .default) throws where Path: FSFullPath {
        try fileManager.copyItem(at: self.url, to: path.url)
    }
    
    /// Moves the file or directory at the specified path to a new location synchronously.
    func move<Path>(to path: Path,
                    using fileManager: FileManager = .default) throws where Path: FSFullPath {
        try fileManager.moveItem(at: self.url, to: path.url)
    }
    /// Removes the file or directory at the specified path.
    func remove(using fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: self.url)
    }
    
    /// Creates a directory with given attributes at the specified path.
    func createDirectory(withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]? = nil,
                         using fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: self.url,
                                        withIntermediateDirectories: createIntermediates,
                                        attributes: attributes)
    }
    /// Creates a file with the specified content and attributes at the given location.
    func createFile(contents data: Data? = nil,
                    attributes attr: [FileAttributeKey : Any]? = nil,
                    using fileManager: FileManager = .default) -> Bool {
        return fileManager.createFile(atPath: self.string,
                                      contents: data,
                                      attributes: attr)
    }
    
    func contentsOfDirectory(options mask: FileManager.DirectoryEnumerationOptions = [],
                             using fileManager: FileManager = .default) throws -> [FSPath]{
        let resources = try fileManager.contentsOfDirectory(at: self.url,
                                                            includingPropertiesForKeys:
                                                                nil,
                                                            options: mask)
        
        var rtn: [FSPath] = []
        for r in resources {
            rtn.append(.init(r.lastPathComponent, relativeTo: FSPath(self)))
        }
        
        return rtn
    }
}




