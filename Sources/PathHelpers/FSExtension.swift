//
//  FSExtension.swift
//  
//
//  Created by Tyler Anger on 2022-04-24.
//

import Foundation

/// A FileSystem File Extenions
public struct FSExtension: CustomStringConvertible {
    public let description: String
    private let lowered: String
    public init(_ ext: String) {
        self.description = ext
        self.lowered = ext.lowercased()
    }
}

extension FSExtension: Comparable {
    public static func ==(lhs: FSExtension, rhs: FSExtension) -> Bool {
        return lhs.lowered == rhs.lowered
    }
    
    public static func <(lhs: FSExtension, rhs: FSExtension) -> Bool {
        return lhs.lowered < rhs.lowered
    }
}

extension FSExtension: Hashable {
    #if !swift(>=4.2)
    public var hashValue: Int { return self.lowered.hashValue }
    #endif
    
}
