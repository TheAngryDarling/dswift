//
//  String+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2018-12-04.
//

import Foundation
import SwiftPatches

//extension String: Error { }

internal extension String {
    /// Optional initializer that taks an optional Data object
    /// This is a helper init do simplify conditional if let statements
    /// and not have to check of data exists or not first
    init?(optData data: Data?, encoding: String.Encoding) {
        guard let dta = data else { return nil }
        guard let s = String(data: dta, encoding: encoding) else {
            return nil
        }
        self = s
    }
    
    /// Provides a complate range of the given string
    var completeRange: Range<String.Index> {
        return Range<String.Index>(uncheckedBounds: (lower: self.startIndex, upper: self.endIndex))
    }
    
    /// Provides a complete NSRange of the given string
    var completeNSRange: NSRange {
        return NSRange(self.completeRange, in: self)
    }
    
    /// Repeats the given string n times
    func repeated(_ times: Int) -> String {
        return String(repeating: self, count: times)
    }
    
    
    /// Finds the last index of a given string
    func lastIndex(of: String) -> String.Index? {
        guard let r = self.range(of: of, options: .backwards) else { return nil }
        return r.lowerBound
    }
    
    /// Generates a random string of a given length (default 20 characters)
    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        
        for _ in 0..<length {
            #if os(Linux)
            let randomValue = Foundation.random() % base.count
            #else
            let randomValue = Int(arc4random_uniform(UInt32(base.count)))
            #endif
            //let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
    
    /// Counts a the number of times a string occurs
    func countOccurrences<Target>(of string: Target, inRange searchRange: Range<String.Index>? = nil) -> Int where Target : StringProtocol {
        var rtn: Int = 0
        var workingRange: Range<String.Index>? = searchRange ?? Range<String.Index>(uncheckedBounds: (lower: self.startIndex,
                                                                                                      upper: self.endIndex))
        while workingRange != nil {
            guard let r = self.range(of: string, range: workingRange) else {
                break
            }
            rtn += 1
            if r.upperBound == workingRange!.upperBound { workingRange = nil }
            else {
                workingRange = Range<String.Index>(uncheckedBounds: (lower: r.upperBound,
                                                                     upper: workingRange!.upperBound))
            }
        }
        
        return rtn
    }
    
    /// Counts a the number of times a string occurs
    func countOccurrences<Target>(of string: Target, before: String.Index) -> Int where Target : StringProtocol {
        return self.countOccurrences(of: string, inRange: self.startIndex..<before)
    }
    
    /// Trims any spaces from the right side of the given string
    func rtrim() -> String {
        var rtn: String = self
        while rtn.hasSuffix(" ") { rtn.removeLast() }
        return rtn
    }
    
    /// Trims any spaces from the left side of the given string
    func ltrim() -> String {
        var rtn: String = self
        while rtn.hasPrefix(" ") { rtn.removeFirst() }
        return rtn
    }
    
    /// Trims any spaces from both sides of the given string
    func trim() -> String {
        var rtn: String = self
        while rtn.hasPrefix(" ") { rtn.removeFirst() }
        while rtn.hasSuffix(" ") { rtn.removeLast() }
        return rtn
    }
    
    
    
}

// MARK: - Path Properties
internal extension String {
    /// Gets the path components of the given string
    var pathComponents: [String] {
        guard self != "/" else { return [self] }
        var comps = self.components(separatedBy: "/")
        if self.hasPrefix("/") && comps[0] == "" {
            comps[0] = "/"
        }
        if self.hasSuffix("/") && comps[comps.count - 1] == "" {
            comps[comps.count - 1] = "/"
        }
        
        return comps
        
    }
    /// Gets the last path component of the given string
    var lastPathComponent: String {
        let comps = self.pathComponents
        var rtn = comps[comps.count - 1]
        if rtn == "/" && comps.count > 1 { rtn =  comps[comps.count - 2]}
        return rtn
    }
    
    /// Deletes the last path component of the given string
    var deletingLastPathComponent: String {
        var comps = self.pathComponents
        comps.removeLast()
        var startValue = comps.removeFirst()
        if comps.count > 0 && startValue == "/" { startValue = "" }
        let rtn: String = comps.reduce(startValue) { return $0 + "/" + $1 }
        return rtn
    }
    
    /// Gets the path extension of the given string
    var pathExtension: String {
        var comps = self.pathComponents
        if comps.count > 1 && comps[comps.count - 1] == "/" {
            comps.removeLast()
        }
        let file = comps[comps.count - 1]
        guard let idx = file.range(of: ".", options: .backwards)?.lowerBound else {
            return ""
        }
        return String(file.suffix(from: file.index(after: idx)))
    }
    
    /// Deletes the path extension of the given string
    var deletingPathExtension: String {
        var comps = self.pathComponents
        if comps.count > 1 && comps[comps.count - 1] == "/" {
            comps.removeLast()
        }
        if let idx = comps[comps.count - 1].range(of: ".", options: .backwards)?.lowerBound {
            comps[comps.count - 1] = String(comps[comps.count - 1].prefix(upTo: idx))
        }
        var startValue = comps.removeFirst()
        if comps.count > 0 && startValue == "/" { startValue = "" }
        let rtn: String = comps.reduce(startValue) { return $0 + "/" + $1 }
        
        return rtn
    }
    /// Returns a full path of the current relative string combined with the provided base string
    func fullPath(from base: String = FileManager.default.currentDirectoryPath) -> String {
        guard !self.hasPrefix("/") else { return self }
        guard !self.hasPrefix("~/") else {
            return NSString(string: NSString(string: self).expandingTildeInPath).standardizingPath
        }
        
        var rtn: String = base
        if !rtn.hasSuffix("/") { rtn += "/" }
        rtn += self
        return NSString(string: rtn).standardizingPath
    }
    
    var resolvingSymlinksInPath: String {
        return NSString(string: self).resolvingSymlinksInPath
    }
}
// MARK: - Distance Helpers
internal extension String {
    #if swift(>=4.1)
    
    /// Get the distance from the start of the string to the given index
    /// - Parameter index: The index to stop counting at
    /// - Returns: The distance between the beginning of the string to the given index.
    func distance(to index: String.Index) -> Int {
        return self.distance(from: self.startIndex, to: index)
    }
    
    /// Get the distance from the given index to the end of the string
    /// - Parameter index: The index to start counting the distance from
    /// - Returns: The distance between the given index and the end of the string
    func distance(from index: String.Index) -> Int {
        return self.distance(from: index, to: self.endIndex)
    }
    /// Returns the start index offset by the given distance
    func index(offsetBy offset: Int) -> String.Index {
        return self.index(self.startIndex, offsetBy: offset)
    }
    
    func index(before offset: Int) -> String.Index {
        let currentIndex = self.index(offsetBy: offset)
        return self.index(before: currentIndex)
    }
    /// Converts a  Range of String Indexes into a range of String Distances
    func distanceRange(of range: Range<String.Index>) -> Range<Int> {
        let lowerBound = self.distance(to: range.lowerBound)
        let upperBound = self.distance(to: range.upperBound)
        return lowerBound..<upperBound
    }
    #else
    /// Get the distance from the start of the string to the given index
    /// - Parameter index: The index to stop counting at
    /// - Returns: The distance between the beginning of the string to the given index.
    func distance(to index: String.Index) -> String.IndexDistance {
        return self.distance(from: self.startIndex, to: index)
    }
    /// Get the distance from the given index to the end of the string
    /// - Parameter index: The index to start counting the distance from
    /// - Returns: The distance between the given index and the end of the string
    func distance(from index: String.Index) -> String.IndexDistance {
        return self.distance(from: index, to: self.endIndex)
    }
    /// Returns the start index offset by the given distance
    func index(offsetBy offset: String.IndexDistance) -> String.Index {
        return self.index(self.startIndex, offsetBy: offset)
    }
    
    func index(before offset: String.IndexDistance) -> String.Index {
        let currentIndex = self.index(offsetBy: offset)
        return self.index(before: currentIndex)
    }
    /// Converts a  Range of String Indexes into a range of String Distances
    func distanceRange(of range: Range<String.Index>) -> Range<String.IndexDistance> {
        let lowerBound = self.distance(to: range.lowerBound)
        let upperBound = self.distance(to: range.upperBound)
        return lowerBound..<upperBound
    }
    #endif
}

// MARK: - Replacement
internal extension String {
    mutating func replaceSubrange<C>(_ range: Range<Int>, with newElements: C) where C : Collection, C.Element == Character {
        let lowerBound = self.index(offsetBy: range.lowerBound)
        let upperBound = self.index(offsetBy: range.upperBound)
        
        return self.replaceSubrange(lowerBound..<upperBound, with: newElements)
    }
}

internal extension String {
    /// Returns a new string that is the given string encapsulatd with the given prefix and suffix
    func encapsulate(prefix: String, suffix: String) -> String {
        return prefix + self + suffix
    }
    /// Returns a new string that is the given string encapsulated with the provided value
    func encapsulate(_ value: String) -> String {
        return self.encapsulate(prefix: value, suffix: value)
    }
}
