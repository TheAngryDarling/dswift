//
//  commandUsage.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation

extension Commands {
    /// Prints the command usage
    @discardableResult
    static func printUsage(_ args: [String] = []) -> Int32 {
        print("\(dSwiftModuleName) compiles .dswift files into .swift files. Any swift commands are passed along to the swift CLI")
        print("\(dSwiftModuleName) files are like JSP or ASP files.  But use swift as the coding languge and expect the resutls to be swift code for your project")
        print("")
        print("Usage: \(dswiftAppName) --version")
        print("\tPrint version information and exit")
        print("Usage: \(dswiftAppName) --help")
        print("\tDisplay available options")
        print("Usage: \(dswiftAppName) --config")
        print("\tSets up the default config file at \(dswiftSettingsFilePath)")
        print("Usage: \(dswiftAppName) build")
        print("\tGenerates required swift from dswift files and builds all targets")
        print("Usage: \(dswiftAppName) build --target {target}")
        print("\tGenerates all swift from dswift files within a specific target and builds that target")
        print("Usage: \(dswiftAppName) rebuild")
        print("\tGenerates all swift from dswift files and builds all targets")
        print("Usage: \(dswiftAppName) rebuild --target {target}")
        print("\tGenerates all swift from dswift files within a specific target and builds that target")
        print("Usage: \(dswiftAppName) package clean")
        print("\tRemoves all generated files, then calls swift package clean")
        print("Usage: \(dswiftAppName) package reset")
        print("\tRemoves all generated files, then calls swift package reset")
        print("")
        
        #if NO_DSWIFT_PARAMS
        // If no dswift paramters supported, hide its usage section
        #else
            print("\(dSwiftModuleName) Specific Parameter Section:")
            print("\(dSwiftModuleName) section mut begin with \(beginDSwiftSection) and be the first parameter when adding \(dSwiftModuleName) parameters.  To close the \(dSwiftModuleName) section, end with \(endDSwiftSection)")
            print("")
            print("Usage: \(dswiftAppName) --- --swiftPath {path to swift cli to use} --- {rest of commands from above}")
            print("\tSpecifies which swift cli to use when executing swift commands")
            print("")
        #endif
        
        return 0
    }
}
