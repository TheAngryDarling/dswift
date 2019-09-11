//
//  commandPrepConfig.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-24.
//

import Foundation
import XcodeProj

extension Commands {
    private static let defaultConfig: String = """
{
    // The default swift path to use unless specificed in the command line
    "swiftPath": "/usr/bin/swift",

    // Sort files and folders within the project
    // "none":  No sorting
    // "sorted": Sort by name, folders first. Except for root, the root has files before folders and folders are in a special order, and Package.swift will always be at the top
    "xcodeResourceSorting": "sorted",

    // Auto create a license file for the project
    // "none": No license
    // "apache2_0": Apache License 2.0
    // "gnuGPL3_0": GNU GPLv3
    // "gnuAGPL3_0": GNU AGPLv3
    // "gnuLGPL3_0": GNU LGPLv3
    // "mozilla2_0": Mozilla Public License 2.0
    // "mit": MIT License
    // "unlicense": The Unlicense
    // address to file (Local path address, or web address)
    "license": "none",
    
    // The path the the specific read me files.  If set, and the file exists, it will be copied into the project replacing the standard one
    // Valid values are:
    //readme: "{path to read me file for all project types}" OR "generated"
    // OR
    // Please note, each property is optional
    // "readme": {
    //      "executable": "{path to read me file for all executable projects}" OR "generated",
    //      "library": "{path to read me file for all library projects}" OR "generated",
    //      "sysMod": "{path to read me file for all system-module projects}" OR "generated",
    // },

    // Author Name.  Used when generated README.me as the author name
    // If author name is not set, the application wil try and use env variable REAL_DISPLAY_NAME if set otherwise use the current use display name from the system
    // "authorName": "YOUR NAME HERE",

    // Regenerate Xcode Project (If already exists) when package is updated
    "regenerateXcodeProject": false,

    // Your public repositor information.  This is used when auto-generating readme files
    // "repository": "https://github.com/YOUR REPOSITORY" <-- Sets the Service URL and repository name
    // OR
    // Please note, serviceName and repositoryName are optional
    // "repository": {
    //      "serviceName": "GitHub",
    //      "serviceURL": "https://github.com/YOUR REPOSITORY",
    //      "repositoryName": "YOUR REPOSITORY NAME",
    // }    
}
"""
    /// Method for setting up default dswift configuration
    static func commandConfig(_ args: [String]) -> Int32 {
        let url = URL(fileURLWithPath: NSString(string: dswiftSettingsFilePath).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath()
        do {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                print("File '\(dswiftSettingsFilePath)' already exists")
                return 0
            }
            
            var configStr = defaultConfig
            if let userDisplayName = XcodeProjectBuilders.UserDetails().displayName, userDisplayName != "root" {
                configStr = configStr.replacingOccurrences(of: "// \"authorName\": \"YOUR NAME HERE\",", with: "\"authorName\": \"\(userDisplayName)\",")
            }
            try configStr.write(to: url, atomically: true, encoding: .utf8)
            
            return 0
            
        } catch {
            errPrint("An error has occured:\n\(error)")
            return 1
        }
    }
}
