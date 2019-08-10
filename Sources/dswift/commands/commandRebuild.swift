//
//  commandRebuild.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation

extension Commands {
    /// Command that rebuild all dswift files then calls swift build
    static func commandRebuild(_ args: [String]) throws -> Int32 {
        let returnCode: Int32 = try commandDSwiftBuild(args)
        guard returnCode == 0 else { return returnCode }
        var args = args
        args[0] = "build"
        return Commands.commandSwift(args)
    }
}
