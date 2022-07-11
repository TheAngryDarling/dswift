//
//  File 2.swift
//  
//
//  Created by Tyler Anger on 2022-04-24.
//

import Foundation

/// Structure representing a File System Path
/// That will return nil instead of throwing errors
/// if any occurs
public struct FSSafePath: FSFullPath {
    
    public fileprivate(set) var string: String
    
    private let _basePath: Any?
    public var basePath: FSSafePath? { return self._basePath as? FSSafePath }
    
    public init(_ path: String,
                relativeTo base: FSSafePath?) {
        self.string = FSSafePath.fullPath(for: path, with: base)
        self._basePath = base
    }
    
    public init(_ path: FSPath) {
        self.string = path.string
        if let bP = path.basePath {
            self._basePath = FSSafePath(bP)
        } else {
            self._basePath = nil
        }
    }
}

public extension FSSafePath {
    mutating func deleteLastComponent() {
        guard !self.string.isEmpty else {
            return
        }
        var range = self.string.startIndex..<self.string.endIndex
        if self.string.hasSuffix(self.componentSeparatorStr) {
            range = self.string.startIndex..<self.string.index(before: self.string.endIndex)
        }
        guard let r = self.string.range(of: self.componentSeparatorStr,
                                        options: .backwards,
                                        range: range) else {
            return
        }
        self.string = String(self.string[..<r.lowerBound])
    }
    mutating func deleteExtension() {
        /// search range of "."
        var range = self.string.startIndex..<self.string.endIndex
        // find the last component separator
        if let r = self.string.range(of: self.componentSeparatorStr, options: .backwards) {
            range = r
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
        var workingString = self.string
        var workingComponent = component
        if workingString.hasSuffix(self.componentSeparatorStr) {
            workingString.removeLast()
        }
        if workingComponent.hasPrefix(self.componentSeparatorStr) {
            workingComponent.removeFirst()
        }
        
        self.string = workingString + self.componentSeparatorStr + workingComponent
    }
    
    mutating func appendExtension(_ ext: String) {
        self.string += ".\(ext)"
    }
}



public extension FSSafePath {
    /// Returns the path modification date if available
    func modificationDate(using fileManager: FileManager = .default) -> Date? {
        guard let attr = try? fileManager.attributesOfItem(atPath: self.string) else {
            return nil
        }
        return attr[FileAttributeKey.modificationDate] as? Date
    }
    /// Returns the path creation date if available
    func creationDate(using fileManager: FileManager = .default) -> Date? {
        guard let attr = try? fileManager.attributesOfItem(atPath: self.string) else {
            return nil
        }
        return attr[FileAttributeKey.creationDate] as? Date
    }
    
    @discardableResult
    func setPosixPermissions(_ permission: UInt,
                             using fileManager: FileManager) -> Bool {
        
        do {
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: permission)],
                                          ofItemAtPath: self.string)
            return true
        } catch {
            return false
        }
        
    }
    
    /// Copies the item at the specified path to a new location synchronously.
    @discardableResult
    func copy<Path>(to path: Path,
                    using fileManager: FileManager = .default) -> Bool where Path: FSFullPath {
        do {
            try fileManager.copyItem(at: self.url, to: path.url)
            return true
        } catch {
            return false
        }
    }
    
    /// Moves the file or directory at the specified path to a new location synchronously.
    @discardableResult
    func move<Path>(to path: Path,
                    using fileManager: FileManager = .default) -> Bool where Path: FSFullPath {
        do {
            try fileManager.moveItem(at: self.url, to: path.url)
            return true
        } catch {
            return false
        }
    }
    /// Removes the file or directory at the specified path.
    @discardableResult
    func remove(using fileManager: FileManager = .default) -> Bool {
        do {
            try fileManager.removeItem(at: self.url)
            return true
        } catch {
            return false
        }
    }
    
    /// Creates a directory with given attributes at the specified path.
    func createDirectory(withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]? = nil,
                         using fileManager: FileManager = .default) -> Bool {
        do {
            try fileManager.createDirectory(at: self.url,
                                            withIntermediateDirectories: createIntermediates,
                                            attributes: attributes)
            return true
        } catch {
            return false
        }
    }
    /// Creates a file with the specified content and attributes at the given location.
    func createFile(contents data: Data? = nil,
                    attributes attr: [FileAttributeKey : Any]? = nil,
                    using fileManager: FileManager = .default) -> Bool {
        return fileManager.createFile(atPath: self.string,
                                      contents: data,
                                      attributes: attr)
    }
    
    @discardableResult
    func contentsOfDirectory(options mask: FileManager.DirectoryEnumerationOptions = [],
                             using fileManager: FileManager = .default) -> [FSPath]? {
        guard let resources = try? fileManager.contentsOfDirectory(at: self.url,
                                                            includingPropertiesForKeys:
                                                                nil,
                                                                   options: mask) else {
            return nil
        }
        
        var rtn: [FSPath] = []
        for r in resources {
            rtn.append(.init(r.lastPathComponent, relativeTo: FSPath(self)))
        }
        
        return rtn
    }
}

