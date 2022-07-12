//
//  commandVersion.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-25.
//

import Foundation
import CLIWrapper


extension Commands {
    /// Prints the current command version
    public func commandVersion(_ parent: CLICommandGroup,
                               _ argumentStartingAt: Int,
                               _ arguments: inout [String],
                               _ environment: [String: String]?,
                               _ currentDirectory: URL?) throws -> Int32 {
        self.console.print("\(dSwiftModuleName) version \(dSwiftVersion)")
        return 0
    }
}
