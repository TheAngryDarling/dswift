//
//  commandXcodeBuild.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-22.
//

import Foundation

extension Commands {
    /// Command for executing in Xcode Script Build Phase
    static func commandXcodeBuild(_ args: [String]) throws -> Int32 {
        guard isRunningFromXcode else {
            errPrint("This command can only be executed from Xcode")
            return 1
        }

        let currentWorkingDir = FileManager.default.currentDirectoryPath
        if let path = ( ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? ProcessInfo.processInfo.environment["SRCROOT"] ?? ProcessInfo.processInfo.environment["SOURCE_ROOT"]) {
            FileManager.default.changeCurrentDirectoryPath(path)
        }
        
        defer {
            FileManager.default.changeCurrentDirectoryPath(currentWorkingDir)
        }
       return try commandXcodeDSwiftBuild(args)
    }
}
