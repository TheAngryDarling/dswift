//
//  FSPathObject.swift
//
//
//  Created by Tyler Anger on 2022-04-24.
//

import Foundation

public protocol FSPathObject: Codable, Equatable, CustomStringConvertible {
    /// The character used to separate each path component
    static var ComponentSeparator: Character { get }
    /// The character uesd to separate each path from a list of paths
    static var PathSeparator: Character { get }
    
    /// The File System local path.
    /// Does not look at base path
    var string: String { get }
    
    /// Indicator if the path is a relative path
    var isRelativePath: Bool { get }
    /// Indicator if the path is a full path
    var isFullPath: Bool { get }
    
    /// The base path for this path
    ///
    /// If this path is absolute then this will be nil
    var basePath: Self? { get }
    
    /// Create new File System Path Object
    init(_ path: String)
    /// Create new File System Path Object
    init(_ path: String, relativeTo base: Self?)
    
    /// Delete the last path component from the relative path
    mutating func deleteLastComponent()
    /// Delete the path exetnsion IF one exists
    mutating func deleteExtension()
    /// Append a path component to the path
    mutating func appendComponent(_ component: String)
    /// Append components to the path
    mutating func appendComponents(_ components: [String])
    /// Append relative path to the path
    mutating func appendRelativePath<Relative>(_ path: Relative) where Relative: FSRelativePathObject
    /// Add the extension to the path
    mutating func appendExtension(_ ext: String)
    /// Add the extension to the path
    mutating func appendExtension(_ ext: FSExtension)
    
    
    static func +(lhs: Self, rhs: String) -> Self
    static func <(lhs: Self, rhs: Self) -> Bool
}

public extension FSPathObject {
    #if os(Windows)
    static var ComponentSeparator: Character { return "\\" }
    static var PathSeparator: Character { return ";" }
    #else
    static var ComponentSeparator: Character { return "/" }
    static var PathSeparator: Character { return ":" }
    #endif
}

internal extension FSPathObject {
    static var ComponentSeparatorStr: String { return "\(Self.ComponentSeparator)" }
    static var PathSeparatorStr: String { return "\(Self.PathSeparator)"  }
    
    var componentSeparatorStr: String { return Self.ComponentSeparatorStr }
    var pathSeparatorStr: String  { return Self.PathSeparatorStr }
}

public extension FSPathObject {
    
    init(_ path: String) {
        self.init(path, relativeTo: nil)
    }
}

public extension FSPathObject {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.string)
    }
}

public extension FSPathObject {
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.string == rhs.string
    }
    
    static func ==<RHS>(lhs: Self, rhs: RHS) -> Bool where RHS: FSPathObject {
        return lhs.string == rhs.string
    }
    
    static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.string < rhs.string
    }
    
    static func <<RHS>(lhs: Self, rhs: RHS) -> Bool where RHS: FSPathObject {
        return lhs.string < rhs.string
    }
    
    static func +(lhs: Self, rhs: String) -> Self {
        return .init(lhs.string + rhs, relativeTo: lhs.basePath)
    }
    
}

// MARK: - Properties
public extension FSPathObject {
    
    internal static func isAbsolutePath(_ path: String) -> Bool {
        #if os(Windows)
            guard let r = path.range(of: Self.ComponentSeparatorStr) else {
                return false
            }
            let str = String(path[..<r.lowerBound])
            return rtn.contains(":")
        #else
            return path.hasPrefix(Self.ComponentSeparatorStr) ||
                   path.hasPrefix("~")
        #endif
    }
    
    internal static func fullPath(for path: String, with base: Self?) -> String {
        var workingPath = path
        if workingPath != Self.ComponentSeparatorStr &&
            workingPath.hasSuffix(Self.ComponentSeparatorStr) {
            workingPath.removeLast()
        }
        if !Self.isAbsolutePath(workingPath),
           let b = base {
            workingPath = b.string + Self.ComponentSeparatorStr + workingPath
        }
        return workingPath
    }
    /// Gets the path components of the given string
    var components: [String] {
        let path = self.string
        var components = path.split(separator: Self.ComponentSeparator).map(String.init)
        #if !os(Windows)
        if path.hasPrefix(self.componentSeparatorStr) {
            components.insert(self.componentSeparatorStr, at: 0)
        }
        #endif
        return components
    }
    
    var hasSubDirectories: Bool {
        return self.string.contains(self.componentSeparatorStr) ||
              (self.basePath?.hasSubDirectories ?? false)
    }
    
    var isRelativePath: Bool {
        return !Self.isAbsolutePath(self.string)
    }
    
    var isFullPath: Bool {
        return Self.isAbsolutePath(self.string)
    }

    
    var description: String { return self.string }
    
    /// Gets the last path component of the given string
    var lastComponent: String {
        return self.components.last ?? ""
    }
    
    /// Gets the path extension of the given string
    var `extension`: FSExtension? {
        let file = self.lastComponent
        guard let r = file.range(of: ".", options: .backwards) else {
            return nil
        }
        return FSExtension(String(file[r.upperBound..<file.endIndex]))
    }
}
 
// MARK: - Methods
public extension FSPathObject {
    /// Deletes the last path component of the given string
    func deletingLastComponent() -> Self {
        var rtn = Self(self.string, relativeTo: self.basePath)
        rtn.deleteLastComponent()
        return rtn
    }
    
    func appendingComponent(_ component: String) -> Self {
        var rtn = Self(self.string, relativeTo: self.basePath)
        rtn.appendComponent(component)
        return rtn
    }
    
    func appendingComponents(_ component: [String]) -> Self {
        let subPath = components.joined(separator: "\(Self.ComponentSeparator)")
        return self.appendingComponent(subPath)
    }
    
    func appendingRelativePath<Relative>(_ path: Relative) -> Self where Relative: FSRelativePathObject {
        return self.appendingComponent(path.string)
    }
    
    
    
    /// Deletes the path extension of the given string
    func deletingExtension() -> Self {
        var rtn = Self(self.string, relativeTo: self.basePath)
        rtn.deleteExtension()
        return rtn
    }
    
    func appendingExtension(_ ext: String) -> Self {
        var rtn = Self(self.string, relativeTo: self.basePath)
        rtn.appendExtension(ext)
        return rtn
    }
    
    func appendingExtension(_ ext: FSExtension) -> Self {
        return self.appendingExtension(ext.description)
    }
    
    mutating func appendComponents(_ components: [String]) {
        guard components.count > 0 else {
            return
        }
        self.appendComponent(components.joined(separator: "\(Self.ComponentSeparator)"))
    }
    mutating func appendRelativePath<Relative>(_ path: Relative) where Relative: FSRelativePathObject {
        self.appendComponent(path.string)
    }
    
    mutating func appendExtension(_ ext: FSExtension) {
        self.appendExtension(ext.description)
    }
    
    
    /// Returns the display name of the file or directory at a specified path.
    func displayName(using fileManager: FileManager = .default) -> String {
        return fileManager.displayName(atPath: self.string)
    }
                                 
    func fullPath(referencing base: FSPath = FSPath(FileManager.default.currentDirectoryPath)) -> FSPath {
        guard !self.isFullPath else {
            return FSPath(self).standardizingPath
        }
        return FSPath(self.string,
                      relativeTo: FSPath(base.string)).standardizingPath
    }
    
    
}

// MARK: - String Manipulation
public extension FSPathObject {
    
    subscript(_ range: Range<String.Index>) -> String {
        return String(self.string[range])
    }
    
    
    func replacingOccurrences<Target, Replacement>(of target: Target,
                                                   with replacement: Replacement,
                                                   options: String.CompareOptions = []) -> Self where Target : StringProtocol, Replacement : StringProtocol {
        let string = self.string
        guard string.contains("\(target)") else {
            return self
        }
        return .init(string.replacingOccurrences(of: target,
                                                      with: replacement,
                                                      options: options),
                     relativeTo: nil)
    }
    
    func range<T>(of aString: T,
                  options mask: String.CompareOptions = [],
                  range searchRange: Range<String.Index>? = nil,
                  locale: Locale? = nil) -> Range<String.Index>? where T : StringProtocol {
        return self.string.range(of: aString,
                                 options: mask,
                                 range: searchRange,
                                 locale: locale)
    }
    
    func range<Path>(of path: Path,
                     options mask: String.CompareOptions = [],
                     range searchRange: Range<String.Index>? = nil,
                     locale: Locale? = nil) -> Range<String.Index>? where Path: FSPathObject {
        return self.range(of: path.string,
                          options: mask,
                          range: searchRange,
                          locale: locale)
    }
}
