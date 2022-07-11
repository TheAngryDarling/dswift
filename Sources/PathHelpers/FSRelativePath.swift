//
//  FSRelativePath.swift
//  
//
//  Created by Tyler Anger on 2022-04-25.
//

import Foundation

public struct FSRelativePath: FSRelativePathObject, ExpressibleByStringLiteral {
    
    public fileprivate(set) var string: String
    
    private let _basePath: Any?
    public var basePath: FSRelativePath? { return self._basePath as? FSRelativePath }
    
    public init(_ path: String, relativeTo base: FSRelativePath?) {
        self.string = FSRelativePath.fullPath(for: path, with: base)
        self._basePath = base
    }
    
    public init(stringLiteral value: String) {
        self.init(value, relativeTo: nil)
    }
}

public extension FSRelativePath {
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
        let workingString = self.string
        var workingComponent = component
        
        if workingComponent.hasPrefix(self.componentSeparatorStr) {
            workingComponent.removeFirst()
        }
        
        self.string = workingString + self.componentSeparatorStr + workingComponent
    }
    
    mutating func appendExtension(_ ext: String) {
        self.string += ".\(ext)"
    }
}
