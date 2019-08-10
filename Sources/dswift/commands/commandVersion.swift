//
//  commandVersion.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-25.
//

import Foundation


extension Commands {
    /// Prints the current command version
    static func commandVersion(_ args: [String]) throws -> Int32 {
        print("\(dSwiftModuleName) version \(dSwiftVersion)")
        return 0
    }
}
