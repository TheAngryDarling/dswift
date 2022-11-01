import XCTest
import Dispatch
import UnitTestingHelper
import CodeTimer
import VersionKit
import XcodeProj
import PBXProj
import CLIWrapper
import CLICapture
import JSONCommentCleaner
@testable import dswiftlib
@testable import dswiftapp
@testable import PathHelpers


extension Character {
    
    #if !swift(>=5.0)
    /// A Boolean value indicating whether this character represents whitespace, including newlines.
    var isWhitespace: Bool {
        return CharacterSet.whitespacesAndNewlines.contains(self.unicodeScalars.first!)
    }
    #endif
    
    var isPeriod: Bool { return self == "." }
    
    var isAcceptableBeginningOfWord: Bool {
        let acceptableBeginningCharacters: [Character] = [" ", "'", "\"", "(", "[", "{"]
        return self.isWhitespace || acceptableBeginningCharacters.contains(self)
    }
    
    var isAcceptableEndingOfWord: Bool {
        let acceptableBeginningCharacters: [Character] = [" ", "'", "\"", ")", "]", "}", "."]
        return self.isWhitespace || acceptableBeginningCharacters.contains(self)
    }
}

private struct IDCLI {
    
    private static func buildProcess(arguments: [String] = [],
                                     environment: [String: String] = ProcessInfo.processInfo.environment) -> Process {
        let idProcess = Process()
        idProcess.executable = URL(fileURLWithPath: "/usr/bin/id")
        idProcess.arguments = arguments
        idProcess.environment = environment
        
        return idProcess
        
    }
    
    private static func grapSTDOut(_ pipe: Pipe) -> String? {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard var outputString = String(data: data, encoding: .utf8) else {
            return nil
        }
        outputString = outputString.replacingOccurrences(of: "\r\n", with: "\n")
        while outputString.hasSuffix("\n") {
            outputString.removeLast()
        }
        return outputString
    }
    public static func getUserID() -> Int? {
        let process = IDCLI.buildProcess(arguments: ["-u"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.execute()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            guard let outputString = IDCLI.grapSTDOut(pipe) else {
                return nil
            }
            
            guard let uid = Int(outputString) else {
                return nil
            }
            return uid
        } catch {
            return nil
        }
    }
    public static func getUserName() -> String? {
        let process = IDCLI.buildProcess(arguments: ["-u", "-n"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.execute()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            guard let outputString = IDCLI.grapSTDOut(pipe) else {
                return nil
            }
            return outputString
        } catch {
            return nil
        }
    }
    
    public static func getGroupID() -> Int? {
        let process = IDCLI.buildProcess(arguments: ["-g"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.execute()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            guard let outputString = IDCLI.grapSTDOut(pipe) else {
                return nil
            }
            
            guard let uid = Int(outputString) else {
                return nil
            }
            return uid
        } catch {
            return nil
        }
    }
    
    public static func getGroupName() -> String? {
        let process = IDCLI.buildProcess(arguments: ["-g", "-n"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.execute()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }
            guard let outputString = IDCLI.grapSTDOut(pipe) else {
                return nil
            }
            return outputString
        } catch {
            return nil
        }
    }
}

class dswiftlibTests: XCExtenedTestCase {
    
    override class func setUp() {
        self.initTestingFile()
    }
    
    
    
    public static let defaultConfig: String = """
{
    // (Optional, If not set \(DSwiftSettings.defaultSwiftPath) is used) The default swift path to use unless specificed in the command line
    // "swiftPath": "\(DSwiftSettings.defaultSwiftPath)",

    /*
    Sort files and folders within the project
    "none":  No sorting
    "sorted": Sort by name, folders first. Except for root, the root has files before folders and folders are in a special order, and Package.swift will always be at the top
    */
    "xcodeResourceSorting": "none",

    /*
    Auto create a license file for the project
        "none": No license
        "apache2_0": Apache License 2.0
        "gnuGPL3_0": GNU GPLv3
        "gnuAGPL3_0": GNU AGPLv3
        "gnuLGPL3_0": GNU LGPLv3
        "mozilla2_0": Mozilla Public License 2.0
        "mit": MIT License
        "unlicense": The Unlicense
        address to file (Local path address, or web address)
    */
    "license": "none",
    
    // The path the the specific read me files.  If set, and the file exists, it will be copied into the project replacing the standard one
    // Valid values are:
    //readme: "{path to read me file for all project types}" OR "generated"
    // OR
    // Please note, each property is optional
    // "readme": {
    //      "executable": "{path to read me file for all executable projects}" OR "generated",
    //      "library": "{path to read me file for all library projects}" OR "generated",
    //      "system-module": "{path to read me file for all system-module projects}" OR "generated",
    //      "other project type": "{path to read me file for other project type}" OR "generated",
    //      "default": "{path to read me file for all other project types}" OR "generated",
    // },

    # Author Name.  Used when generated README.md as the author name
    # If author name is not set, the application wil try and use env variable REAL_DISPLAY_NAME if set otherwise use the current use display name from the system
    # "authorName": "YOUR NAME HERE",

    // Provides an indicator of when to add the build rules to the Xcode Project.
    //      always: Even if there are no custom build files
    //      whenNeeded: Only when there are custom build files
    // "whenToAddBuildRules": "always" OR "whenNeeded",

    // (Optional, Default: false) Generate Xcode Project on package creation if the flag is true
    // "generateXcodeProjectOnInit": true,
    // "generateXcodeProjectOnInit": {
    //      "library": true,
    //      "executable": true,
    //      "system-module": true,
    //      "other project type": true,
    //      "default": true,
    // },

    // Regenerate Xcode Project (If already exists) when package is updated
    "regenerateXcodeProject": false,

    // Your public repositor information.  This is used when auto-generating readme files
    // "repository": "https://github.com/YOUR REPOSITORY", <-- Sets the Service URL and repository name
    // OR
    // Please note, serviceName and repositoryName are optional
    // "repository": {
    //      "serviceName": "GitHub",
    //      "serviceURL": "https://github.com/YOUR REPOSITORY",
    //      "repositoryName": "YOUR REPOSITORY NAME",
    // },

    // (Optional, Default: true) Lock generated files from being modified manually
    // "lockGenratedFiles": true,

    // (Optional, Default: false) Indicator if generated files should be kepted in Xcode Project when generating / updating project
    // "includeGeneratedFilesInXcodeProject": false,

    // (Optional, Default: never) Indicator if, when generating Xcode Project file, the application should install SwiftLint Build Phase Run Script if SwiftLint is installed.  Options: always, whenAvailable, never
    // "includeSwiftLintInXcodeProject": "never",

    // (Optional, Default: false) Indicator if we should try to auto install any missing system packages from the package manager
    // when requirements are found within the project, otherwise we will just give a warning.
    // Note: If dswift was built with the flag AUTO_INSTALL_PACKAGES.  This property is always true no matter what the configuration value is set to
    // "autoInstallMissingPackages": false,
    
    // (Optional, Default: null/nil) Provides an option to override the default gitignore contents that dswift generates
    // "defaultGitIgnore": {
    //      "items": [
    //          "Rule",
    //          "# Comment",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //                  "# Comment",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                          "# Comment",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },

    // (Optional, Default: null/nil) Provides an option to add additional items to the gitignore.
    // This structure is the same as defaultGitIgnore.  This object will be combined with the
    // default gitignore in the following way:
    // 1. All comments are ignored.
    // 2. I will first try and and see if the rule exists somewhere else before adding
    // 3. If the default gitignore has the same section with no description, the addition description will
    //   be copied
    // 4. Any sections/subsections that become empty due to rules already existing will not be added
    
    // "gitIgnoreAdditions": {
    //      "items": [
    //          "Rule",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },
}
"""
    
    public static let openCommentConfig: String = """
{
    // (Optional, If not set \(DSwiftSettings.defaultSwiftPath) is used) The default swift path to use unless specificed in the command line
    // "swiftPath": "\(DSwiftSettings.defaultSwiftPath)",

    /*
    Sort files and folders within the project
    "none":  No sorting
    "sorted": Sort by name, folders first. Except for root, the root has files before folders and folders are in a special order, and Package.swift will always be at the top
    */
    "xcodeResourceSorting": "none",

    /*
    Auto create a license file for the project
        "none": No license
        "apache2_0": Apache License 2.0
        "gnuGPL3_0": GNU GPLv3
        "gnuAGPL3_0": GNU AGPLv3
        "gnuLGPL3_0": GNU LGPLv3
        "mozilla2_0": Mozilla Public License 2.0
        "mit": MIT License
        "unlicense": The Unlicense
        address to file (Local path address, or web address)
    * /
    "license": "none",
    
    // The path the the specific read me files.  If set, and the file exists, it will be copied into the project replacing the standard one
    // Valid values are:
    //readme: "{path to read me file for all project types}" OR "generated"
    // OR
    // Please note, each property is optional
    // "readme": {
    //      "executable": "{path to read me file for all executable projects}" OR "generated",
    //      "library": "{path to read me file for all library projects}" OR "generated",
    //      "system-module": "{path to read me file for all system-module projects}" OR "generated",
    //      "other project type": "{path to read me file for other project type}" OR "generated",
    //      "default": "{path to read me file for all other project types}" OR "generated",
    // },

    # Author Name.  Used when generated README.md as the author name
    # If author name is not set, the application wil try and use env variable REAL_DISPLAY_NAME if set otherwise use the current use display name from the system
    # "authorName": "YOUR NAME HERE",

    // Provides an indicator of when to add the build rules to the Xcode Project.
    //      always: Even if there are no custom build files
    //      whenNeeded: Only when there are custom build files
    // "whenToAddBuildRules": "always" OR "whenNeeded",

    // (Optional, Default: false) Generate Xcode Project on package creation if the flag is true
    // "generateXcodeProjectOnInit": true,
    // "generateXcodeProjectOnInit": {
    //      "library": true,
    //      "executable": true,
    //      "system-module": true,
    //      "other project type": true,
    //      "default": true,
    // },

    // Regenerate Xcode Project (If already exists) when package is updated
    "regenerateXcodeProject": false,

    // Your public repositor information.  This is used when auto-generating readme files
    // "repository": "https://github.com/YOUR REPOSITORY", <-- Sets the Service URL and repository name
    // OR
    // Please note, serviceName and repositoryName are optional
    // "repository": {
    //      "serviceName": "GitHub",
    //      "serviceURL": "https://github.com/YOUR REPOSITORY",
    //      "repositoryName": "YOUR REPOSITORY NAME",
    // },

    // (Optional, Default: true) Lock generated files from being modified manually
    // "lockGenratedFiles": true,

    // (Optional, Default: false) Indicator if generated files should be kepted in Xcode Project when generating / updating project
    // "includeGeneratedFilesInXcodeProject": false,

    // (Optional, Default: never) Indicator if, when generating Xcode Project file, the application should install SwiftLint Build Phase Run Script if SwiftLint is installed.  Options: always, whenAvailable, never
    // "includeSwiftLintInXcodeProject": "never",

    // (Optional, Default: false) Indicator if we should try to auto install any missing system packages from the package manager
    // when requirements are found within the project, otherwise we will just give a warning.
    // Note: If dswift was built with the flag AUTO_INSTALL_PACKAGES.  This property is always true no matter what the configuration value is set to
    // "autoInstallMissingPackages": false,
    
    // (Optional, Default: null/nil) Provides an option to override the default gitignore contents that dswift generates
    // "defaultGitIgnore": {
    //      "items": [
    //          "Rule",
    //          "# Comment",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //                  "# Comment",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                          "# Comment",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },

    // (Optional, Default: null/nil) Provides an option to add additional items to the gitignore.
    // This structure is the same as defaultGitIgnore.  This object will be combined with the
    // default gitignore in the following way:
    // 1. All comments are ignored.
    // 2. I will first try and and see if the rule exists somewhere else before adding
    // 3. If the default gitignore has the same section with no description, the addition description will
    //   be copied
    // 4. Any sections/subsections that become empty due to rules already existing will not be added
    
    // "gitIgnoreAdditions": {
    //      "items": [
    //          "Rule",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },
}
"""
    
    public static let openStringConfig: String = """
{
    // (Optional, If not set \(DSwiftSettings.defaultSwiftPath) is used) The default swift path to use unless specificed in the command line
    // "swiftPath": "\(DSwiftSettings.defaultSwiftPath)",

    /*
    Sort files and folders within the project
    "none":  No sorting
    "sorted": Sort by name, folders first. Except for root, the root has files before folders and folders are in a special order, and Package.swift will always be at the top
    */
    "xcodeResourceSorting": "none,

    /*
    Auto create a license file for the project
        "none": No license
        "apache2_0": Apache License 2.0
        "gnuGPL3_0": GNU GPLv3
        "gnuAGPL3_0": GNU AGPLv3
        "gnuLGPL3_0": GNU LGPLv3
        "mozilla2_0": Mozilla Public License 2.0
        "mit": MIT License
        "unlicense": The Unlicense
        address to file (Local path address, or web address)
    */
    "license": "none",
    
    // The path the the specific read me files.  If set, and the file exists, it will be copied into the project replacing the standard one
    // Valid values are:
    //readme: "{path to read me file for all project types}" OR "generated"
    // OR
    // Please note, each property is optional
    // "readme": {
    //      "executable": "{path to read me file for all executable projects}" OR "generated",
    //      "library": "{path to read me file for all library projects}" OR "generated",
    //      "system-module": "{path to read me file for all system-module projects}" OR "generated",
    //      "other project type": "{path to read me file for other project type}" OR "generated",
    //      "default": "{path to read me file for all other project types}" OR "generated",
    // },

    # Author Name.  Used when generated README.md as the author name
    # If author name is not set, the application wil try and use env variable REAL_DISPLAY_NAME if set otherwise use the current use display name from the system
    # "authorName": "YOUR NAME HERE",

    // Provides an indicator of when to add the build rules to the Xcode Project.
    //      always: Even if there are no custom build files
    //      whenNeeded: Only when there are custom build files
    // "whenToAddBuildRules": "always" OR "whenNeeded",

    // (Optional, Default: false) Generate Xcode Project on package creation if the flag is true
    // "generateXcodeProjectOnInit": true,
    // "generateXcodeProjectOnInit": {
    //      "library": true,
    //      "executable": true,
    //      "system-module": true,
    //      "other project type": true,
    //      "default": true,
    // },

    // Regenerate Xcode Project (If already exists) when package is updated
    "regenerateXcodeProject": false,

    // Your public repositor information.  This is used when auto-generating readme files
    // "repository": "https://github.com/YOUR REPOSITORY", <-- Sets the Service URL and repository name
    // OR
    // Please note, serviceName and repositoryName are optional
    // "repository": {
    //      "serviceName": "GitHub",
    //      "serviceURL": "https://github.com/YOUR REPOSITORY",
    //      "repositoryName": "YOUR REPOSITORY NAME",
    // },

    // (Optional, Default: true) Lock generated files from being modified manually
    // "lockGenratedFiles": true,

    // (Optional, Default: false) Indicator if generated files should be kepted in Xcode Project when generating / updating project
    // "includeGeneratedFilesInXcodeProject": false,

    // (Optional, Default: never) Indicator if, when generating Xcode Project file, the application should install SwiftLint Build Phase Run Script if SwiftLint is installed.  Options: always, whenAvailable, never
    // "includeSwiftLintInXcodeProject": "never",

    // (Optional, Default: false) Indicator if we should try to auto install any missing system packages from the package manager
    // when requirements are found within the project, otherwise we will just give a warning.
    // Note: If dswift was built with the flag AUTO_INSTALL_PACKAGES.  This property is always true no matter what the configuration value is set to
    // "autoInstallMissingPackages": false,
    
    // (Optional, Default: null/nil) Provides an option to override the default gitignore contents that dswift generates
    // "defaultGitIgnore": {
    //      "items": [
    //          "Rule",
    //          "# Comment",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //                  "# Comment",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                          "# Comment",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },

    // (Optional, Default: null/nil) Provides an option to add additional items to the gitignore.
    // This structure is the same as defaultGitIgnore.  This object will be combined with the
    // default gitignore in the following way:
    // 1. All comments are ignored.
    // 2. I will first try and and see if the rule exists somewhere else before adding
    // 3. If the default gitignore has the same section with no description, the addition description will
    //   be copied
    // 4. Any sections/subsections that become empty due to rules already existing will not be added
    
    // "gitIgnoreAdditions": {
    //      "items": [
    //          "Rule",
    //      ],
    //      "sections": [
    //          {
    //              "name": "Section Name",
    //              "description": [
    //                  "Description array separated by lines",
    //              ],
    //              "items": [
    //                  "Rule",
    //              ],
    //              subsections: [
    //                  {
    //                      "name": "Sub Section Name",
    //                      "items": [
    //                          "Rule",
    //                      ],
    //                  },
    //              ]
    //          },
    //      ]
    // },
}
"""
    
    var testTargetPath: FSPath {
        return FSPath(self.testTargetURL.path)
    }
    
    
    let dswiftInfo = DSwiftInfo(moduleName: "Dynamic Swift",
                                appName: "dswift",
                                url: "https://github.com/TheAngryDarling/dswift",
                                version: DSwiftTag.Include.Folder.minimumSupportedTagVersion)
    
    let preloadedDetails = DynamicSourceCodeGenerator.PreloadedDetails(parseDSwiftToolsVersion: DynamicSourceCodeBuilder.parseDSwiftToolsVersion(from:source:console:),
                                                                       parseDSwiftTags: DynamicSourceCodeBuilder.parseDSwiftTags(in:source:project:console:using:))
    
    #if !DOCKER_ALL_BUILD
    let console: Console = .default
    #else
    let console: Console = .null
    #endif
    
    public struct OutputHandler: OptionSet {
        let rawValue: Int
        
        public static let std = OutputHandler(rawValue: 1 << 0)
        public static let buffer = OutputHandler(rawValue: 1 << 1)
        public static let both = OutputHandler(rawValue: (OutputHandler.std.rawValue + OutputHandler.buffer.rawValue))
    }
    
    func testPaths() {
        let pathsForComponents: [String] = ["/file/to/path", "file/to/path", "/"]
        for strPath in pathsForComponents {
            let nsPath = NSString(string: strPath)
            let path = FSPath(strPath)
            
            XCTAssertEqual(nsPath.pathComponents, path.components)
        }
        
        let pathsForDeleting: [String] = ["/file/to/path", "/file/to/path/"]
        for strPath in pathsForDeleting {
            let nsPath = NSString(string: strPath).deletingLastPathComponent
            var path = FSPath(strPath)
            path.deleteLastComponent()
            
            let path2 = FSPath(strPath).deletingLastComponent()
            
            XCTAssertEqual(nsPath, path.string)
            XCTAssertEqual(nsPath, path2.string)
        }
        let testPathBase = "/file/to/"
        for testPath in ["path", "path/"] {
            var url = URL(fileURLWithPath: testPath, relativeTo: URL(fileURLWithPath: testPathBase))
            var path = FSPath(testPath, relativeTo: FSPath(testPathBase))
            repeat {
                //print("\(path.string) =? \(url.path)")
                XCTAssertEqual(path.string, url.path)
                url.deleteLastPathComponent()
                path.deleteLastComponent()
            } while url.path != "/.."
        }
        
        let testFilePath = "/path/to/file.txt"
        
        XCTAssertEqual(FSPath(testFilePath).deletingExtension().string,
                       NSString(string: testFilePath).deletingPathExtension)
        
        XCTAssertEqual(FSSafePath(testFilePath).deletingExtension().string,
                       NSString(string: testFilePath).deletingPathExtension)
        #if _runtime(_ObjC)
        XCTAssertEqual(FSPath(testFilePath).appendingExtension("").string,
                       NSString(string: testFilePath).appendingPathExtension(""))
        XCTAssertEqual(FSSafePath(testFilePath).appendingExtension("").string,
                       NSString(string: testFilePath).appendingPathExtension(""))
        XCTAssertEqual(FSRelativePath(testFilePath).appendingExtension("").string,
                       NSString(string: testFilePath).appendingPathExtension(""))
        #else
        XCTAssertEqual(FSPath(testFilePath).appendingExtension("").string + ".",
                       NSString(string: testFilePath).appendingPathExtension(""))
        XCTAssertEqual(FSSafePath(testFilePath).appendingExtension("").string + ".",
                       NSString(string: testFilePath).appendingPathExtension(""))
        XCTAssertEqual(FSRelativePath(testFilePath).appendingExtension("").string + ".",
                       NSString(string: testFilePath).appendingPathExtension(""))
        #endif
        
        XCTAssertEqual(FSPath(testFilePath).appendingExtension(".newExt").string,
                       NSString(string: testFilePath).appendingPathExtension(".newExt"))
        XCTAssertEqual(FSSafePath(testFilePath).appendingExtension(".newExt").string,
                       NSString(string: testFilePath).appendingPathExtension(".newExt"))
        XCTAssertEqual(FSRelativePath(testFilePath).appendingExtension(".newExt").string,
                       NSString(string: testFilePath).appendingPathExtension(".newExt"))
        
        let testRelFilePath = String(testFilePath[testFilePath.index(after: testFilePath.startIndex)...])
        XCTAssertEqual(FSRelativePath(testRelFilePath).deletingExtension().string,
                       NSString(string: testRelFilePath).deletingPathExtension)
    }
    
    func testPackageLoads() {
        let swiftPath = DSwiftSettings.defaultSwiftPath.string
        let arguments = ["package", "describe", "--type", "json"]
        let projectDir = self.projectURL
        
        // We do this to give each test a fair chance
        // Swift does some caching of the process' current directory
        // in this case our 'projectDir' so we have the file manager
        // do a simple lookup otherwise the first test would take longer
        // to execute.  This could be becuse my project is accessed off
        // of a network share
        let projectDirDuration = Timer.time {
            _ = try? FileManager.default.contentsOfDirectory(atPath: projectDir.path)
        }
        print("Access project dir duration: \(projectDirDuration)")
        do {
            let duration = try Timer.time {
                let process = Process()
                
                if ProcessInfo.processInfo.environment["OS_ACTIVITY_DT_MODE"] != nil {
                    var env =  ProcessInfo.processInfo.environment
                    // this is done or swift gives error
                    env["OS_ACTIVITY_DT_MODE"] = nil
                    process.environment = env
                }
                
                process.executable = URL(fileURLWithPath: swiftPath)
                process.currentDirectory = projectDir
                process.arguments = arguments
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                
                try process.execute()
                process.waitUntilExit()
            }
            print("Manual Process (No ENV Fix) Execution: \(duration)")
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let duration = try Timer.time {
                let process = Process()
                
                var env: [String: String] = [:]
                
                env["USER"] = ProcessInfo.processInfo.environment["USER"]
                env["LOGNAME"] =  ProcessInfo.processInfo.environment["LOGNAME"]
                env["HOME"] =  ProcessInfo.processInfo.environment["HOME"]
                env["PATH"] =  ProcessInfo.processInfo.environment["PATH"]
                env["TMPDIR"] =  ProcessInfo.processInfo.environment["TMPDIR"]
                env["SHELL"] =  ProcessInfo.processInfo.environment["SHELL"]
                env["COMMAND_MODE"] =  ProcessInfo.processInfo.environment["COMMAND_MODE"]
                env["XPC_FLAGS"] =  ProcessInfo.processInfo.environment["XPC_FLAGS"]
                
                env["SSH_AUTH_SOCK"] =  ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"]
                
                env["XPC_SERVICE_NAME"] = "0"
                
                process.environment = env
                
                process.executable = URL(fileURLWithPath: swiftPath)
                process.currentDirectory = projectDir
                process.arguments = arguments
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                
                try process.execute()
                process.waitUntilExit()
            }
            print("Manual Process (Env Fix) Execution: \(duration)")
        } catch {
            XCTFail("\(error)")
        }
        
        
        do {
            let wrapper = SwiftCLIWrapper.init(swiftPath: .init(swiftPath))
            
            
            let ret = try Timer.time {
                _ = try wrapper.cli.executeAndWait(arguments: arguments,
                                                   currentDirectory: projectDir,
                                                   passthrougOptions: .none)
            }
            print("Swift Wrapper (Env Fix) Execution: \(ret)")
        } catch {
            XCTFail("\(error)")
            return
        }
        
        
    }
    
    
    func testJSONCommentBlocks() {
        
        do {
            let json = dswiftlibTests.defaultConfig
            let cleanJSONString = try JSONDefaultCommentCleaner().parse(json)
            
            if let jsonData = XCTAssertsNotNil(cleanJSONString.data(using: .utf8)) {
                XCTAssertsNoThrow(try JSONSerialization.jsonObject(with: jsonData),
                                 "Invalid JSON String:\n\(cleanJSONString)\nFrom:\n\(json)")
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let json = dswiftlibTests.defaultConfig.replacingOccurrences(of: "// \"repository\": \"https://github.com/YOUR REPOSITORY\", <-- Sets the Service URL and repository name",
                                                                   with: "\"repository\": \"http://github.com/TheAngryDarling\",")
            let cleanJSONString = try JSONDefaultCommentCleaner().parse(json)
            
            if let jsonData = XCTAssertsNotNil(cleanJSONString.data(using: .utf8)) {
                XCTAssertsNoThrow(try JSONSerialization.jsonObject(with: jsonData),
                                 "Invalid JSON String:\n\(cleanJSONString)\nFrom:\n\(json)")
            }
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            
            let json = dswiftlibTests.openCommentConfig
            let cleanJSONString = try JSONDefaultCommentCleaner().parse(json)
            XCTFail("Expected an error to be thrown")
            print(cleanJSONString)
        } catch JSONCommentCleaner.ParsingError.unterminatedComment(blockOpening: let opening,
                                                            blockClosing: _,
                                                            atIndex: _,
                                                            line: let line,
                                                            column: let column) {
            
            XCTAssertEqual(opening, "/*")
            XCTAssertEqual(line, 12)
            XCTAssertEqual(column, 5)
            
        } catch {
            XCTFail("\(error)")
            print(dswiftlibTests.openCommentConfig)
        }
        
        do {
            
            let json = dswiftlibTests.openStringConfig
            let cleanJSONString = try JSONDefaultCommentCleaner().parse(json)
            XCTFail("Expected an error to be thrown")
            print(cleanJSONString)
        } catch JSONCommentCleaner.ParsingError.unterminatedString(stringIndicator: let opening,
                                                           atIndex: _,
                                                           line: let line,
                                                           column: let column) {
            
            XCTAssertEqual(opening, "\"")
            XCTAssertEqual(line, 10)
            XCTAssertEqual(column, 29)
            
        } catch {
            XCTFail("\(error)")
            print(dswiftlibTests.openStringConfig)
        }
    }
    func testEncodeDecodeDefaultSettings() {
        guard let settings = XCTAssertsNoThrow(try DSwiftSettings.init(from: dswiftlibTests.defaultConfig)) else {
            return
        }
        
        let encoder = JSONEncoder()
        if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
            #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || swift(>=5.5)
            encoder.outputFormatting.insert(.sortedKeys)
            #endif
        } else {
            // Fallback on earlier versions
            #if swift(>=5.5)
            encoder.outputFormatting.insert(.sortedKeys)
            #endif
        }
        encoder.outputFormatting.insert(.prettyPrinted)
        
        guard let dta = XCTAssertsNoThrow(try encoder.encode(settings)) else {
            return
        }
        
        guard let settings2 = XCTAssertsNoThrow(try JSONDecoder().decode(DSwiftSettings.self,
                                                                         from: dta)) else {
            if let str = String(data: dta, encoding: .utf8) {
                print("Settings:")
                print(str)
            }
            return
        }
        
        XCTAssertEqual(settings, settings2,
        "Decoded Settings does not match original settings")
        
        
    }
    
    func testLicenseText() {
        for license in DSwiftSettings.License.allStandardLicenses + [.none] {
            guard !license.isFile else {
                XCTFail("Should not find file license in allStandardLicenses")
                continue
            }
            
            var testDisplayName: String = ""
            var testBadgeName: String = ""
            var testReadmeText: String = ""
            switch license {
                case .none:
                    testDisplayName = ""
                    testBadgeName = ""
                    testReadmeText = ""
                case .apache2_0:
                    testDisplayName = "Apache License v2.0"
                    testBadgeName = "Apache 2.0"
                    testReadmeText = Licenses.apache2_0_README()
                case .gnuGPL3_0:
                    testDisplayName = "GNU General Public License v3.0"
                    testBadgeName = "GPL v3"
                    testReadmeText = Licenses.gnuGPL3_0_README()
                case .gnuAGPL3_0:
                    testDisplayName = "GNU Affero General Public License v3.0"
                    testBadgeName = "AGPL v3"
                    testReadmeText = Licenses.gnuAGPL3_0_README()
                case .gnuLGPL3_0:
                    testDisplayName = "GNU Lesser General Public License v3.0"
                    testBadgeName = "LGPL v3"
                    testReadmeText = Licenses.gnuLGPL3_0_README()
                case .mozilla2_0:
                    testDisplayName = "Mozilla Public License 2.0"
                    testBadgeName = "MPL 2.0"
                    testReadmeText = Licenses.mozilla2_0_README()
                case .mit:
                    testDisplayName = "MIT"
                    testBadgeName = "MIT"
                    testReadmeText = Licenses.mit_README()
                case .unlicense:
                    testDisplayName = "The Unlicense"
                    testBadgeName = "Unlicense"
                    testReadmeText = Licenses.unlicense_README()
                default:
                    XCTFail("Unknown license '\(license)' found")
                    continue
            }
            
            XCTAssertEqual(license.displayName, testDisplayName)
            XCTAssertEqual(license.badgeName, testBadgeName)
            XCTAssertEqual(license.readmeText(), testReadmeText)
        }
    }
    
    func testReadMeFile() {
        
        let rm = DSwiftSettings.ReadMe(.generated)
        
        let projectName = "TestProject"
        let projectPath = FSPath.root
        let authorName: String? = nil
        
        let testAuthorName = authorName ?? XcodeProjectBuilders.UserDetails().displayName
        
        for license in DSwiftSettings.License.allStandardLicenses + [.none] {
            guard let g = XCTAssertsNoThrow(try rm.generateReadMe(for: "library",
                                                                     withName: projectName,
                                                                     dswiftInfo: dswiftInfo,
                                                                     currentProjectPath: projectPath,
                                                                     authorName: authorName,
                                                                     license: license)) else {
                continue
            }
            
            XCTAssertTrue(g.content.contains("# \(projectName)"),
                          "Could not find '# \(projectName)'")
            
            if let an = testAuthorName {
                XCTAssertTrue(g.content.contains(an),
                              "Could not find Author Name'\(an)'")
            }
            
            if !license.isNone {
                XCTAssertTrue(g.content.contains(license.readmeText(authorName: testAuthorName)),
                              "Chould not find license readme for '\(license.displayName)'")
            }
            //g.content
            //print(g.content)
        }
        
    }
    
    func testStaticStringFiles() {
        let generator = try! StaticFileSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                           console: console)
        
        let sourcePath = FSPath("/path/to/static/source/file.static-dswift")
        let contentPath = "/path/to/content/file.data"
        var staticJSONFile = """
{
    "file": "\(contentPath)",
    "namespace": "StringValues",
    "modifier": "public",
    "name": "testString",
    "type": "text(utf8)"
}
"""
        let staticContentStringFile = """
This is a test and only a test
I hope that this works
"""
        let staticContentData = staticContentStringFile.data(using: .utf8)!
        
        // Test static string file with namespace
        if let content = XCTAssertsNoThrow(try generator.generateSource(sourcePath: sourcePath,
                                                                        staticFile: staticJSONFile,
                                                                        fileContent: staticContentData)) {
            
            var passedTests: Bool = true
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("This file was dynamically generated from '\(sourcePath.lastComponent)' and '\(contentPath)'"),
                                                       "Failed to find generated comment line")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public extension StringValues"),
                                                       "Failed to find namespace and namespace modifier")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("struct testString"),
                                                       "Missing 'testString' object")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public static let string: String"),
                                                       "Missing string property")
            passedTests = passedTests && XCTAssertsTrue(content.source.contains(staticContentStringFile),
                                                       "Missing string value")
            
            
            if !passedTests { print(content.source) }
        }
        
        // Test static string file with no namespace
        staticJSONFile = """
{
    "file": "\(contentPath)",
    "modifier": "public",
    "name": "testString",
    "type": "text(utf8)"
}
"""
        if let content = XCTAssertsNoThrow(try generator.generateSource(sourcePath: sourcePath,
                                                                        staticFile: staticJSONFile,
                                                                        fileContent: staticContentData)) {
            
            var passedTests: Bool = true
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("This file was dynamically generated from '\(sourcePath.lastComponent)' and '\(contentPath)'"),
                                                        "Failed to find generated comment line")
            
            //passedTests = passedTests && XCTAssertsTrue(content.source.contains("public extension StringValues"),
            //                  "Failed to find namespace and namespace modifier")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public struct testString"),
                                                        "Missing 'testString' object")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public static let string: String"),
                                                        "Missing string property")
            passedTests = passedTests && XCTAssertsTrue(content.source.contains(staticContentStringFile),
                                                        "Missing string value")
            
            
            if !passedTests { print(content.source) }
        }
        
    }
    
    func testStaticBinaryFiles() {
        let generator = try! StaticFileSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                           console: console)
        
        let sourcePath = FSPath("/path/to/static/source/file.static-dswift")
        let contentPath = "/path/to/content/file.data"
        var staticJSONFile = """
{
    "file": "\(contentPath)",
    "namespace": "DataValues",
    "modifier": "public",
    "name": "testData",
    "type": "binary"
}
"""
        let staticContentBytes: [UInt8] = [0, 1, 2, 3, 4, 5]
        let staticContentString = staticContentBytes.map({ return String(format: "0x%02X", $0) }).joined(separator: ", ")
        let staticContentData = Data(staticContentBytes)
        
        // Test static string file with namespace
        if let content = XCTAssertsNoThrow(try generator.generateSource(sourcePath: sourcePath,
                                                                        staticFile: staticJSONFile,
                                                                        fileContent: staticContentData)) {
            
            var passedTests: Bool = true
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("This file was dynamically generated from '\(sourcePath.lastComponent)' and '\(contentPath)'"),
                                                        "Failed to find generated comment line")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public extension DataValues"),
                                                        "Failed to find namespace and namespace modifier")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("struct testData"),
                                                        "Missing 'testData' object")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public static var data: Data"),
                                                        "Missing data property")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains(staticContentString),
                                                        "Missing data value")
            
            
            
            if !passedTests { print(content.source) }
        }
        
        // Test static string file with no namespace
        staticJSONFile = """
{
    "file": "\(contentPath)",
    "modifier": "public",
    "name": "testData",
    "type": "binary"
}
"""
        if let content = XCTAssertsNoThrow(try generator.generateSource(sourcePath: sourcePath,
                                                                        staticFile: staticJSONFile,
                                                                        fileContent: staticContentData)) {
            
            var passedTests: Bool = true
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("This file was dynamically generated from '\(sourcePath.lastComponent)' and '\(contentPath)'"),
                                                        "Failed to find generated comment line")
            
            //passedTests = passedTests && XCTAssertsTrue(content.source.contains("public extension StringValues"),
            //               "Failed to find namespace and namespace modifier")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public struct testData"),
                                                        "Missing 'testData' object")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("public static var data: Data"),
                                                        "Missing data property")
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains(staticContentString),
                                                        "Missing data value")
            
            
            if !passedTests { print(content.source) }
        }
    }
    
    func testDSwiftBasic() {
        let swiftProject = SwiftProject(rootPath: .root)
        guard let (dynamicSourceCodeGeneratorTime, generator) = XCTAssertsNoThrow(try Timer.timeWithResults(block: try DynamicSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                                                                                                                  console: console))) else {
            return
        }
        
        if self.isXcodeTesting {
            print("DynamicSourceCodeGenerator init took \(dynamicSourceCodeGeneratorTime)(s)")
        }
        
        let srcPath = self.testTargetPath
            .appendingComponent("testFiles")
            .appendingComponent("basicDSwiftFile.txt")
        
        let className = generator.getNextClassName()
        if let (dynamicSourceCodeBuilderTime, builder) = XCTAssertsNoThrow(try Timer.timeWithResults(block: try DynamicSourceCodeBuilder.init(file: srcPath,
                                                                                                                                              swiftProject: swiftProject,
                                                                        className: className,
                                                                        dswiftInfo: dswiftInfo,
                                                                                                                                              preloadedDetails: preloadedDetails,
                                                                                                                                              console: console,
                                                                                                                                              using: .default))) {
            if self.isXcodeTesting {
                print("DynamicSourceCodeBuilder init took \(dynamicSourceCodeBuilderTime)(s)")
            }
            // Get the generated source code generator
            if let (generateSourceGeneratorTime, generated) = XCTAssertsNoThrow(try Timer.timeWithResults(block: try builder.generateSourceGenerator())) {
                if self.isXcodeTesting {
                    print("Generate Source Generator took \(generateSourceGeneratorTime)(s)")
                }
                var passedTests = true
                if let classDef = generated.range(of: "class \(className)"),
                   let genDef = generated.range(of: "public func generate() -> String {") {
                    
                    // Make sure the the global block is before the class desfition
                   if let globalCodeDef = generated.range(of: "// Global block of code") {
                       passedTests = passedTests && XCTAssertsTrue(classDef.lowerBound > globalCodeDef.lowerBound,
                                     "Global block should be before start of class")
                   }
                    // make sure the static block is after the beginning of the class definition
                    if let classDefCode = generated.range(of: "// In class but out of generate method block of code") {
                        passedTests = passedTests && XCTAssertsTrue(classDefCode.lowerBound > classDef.lowerBound,
                                      "Inclass block should be after start of class definition")
                        passedTests = passedTests && XCTAssertsTrue(genDef.lowerBound > classDefCode.lowerBound,
                                      "Inclass block should be before start of generate method")
                    }
                    // make sure the static block is before the generate method
                    if let genDefCode = generated.range(of: "// In generate block of code") {
                        passedTests = passedTests && XCTAssertsTrue(genDefCode.lowerBound > genDef.lowerBound,
                                      "In generator block should be after start of generate method")
                    }
                }
                if !passedTests { print(generated) }
            }
            if let content = XCTAssertsNoThrow(try generator.generateSource(from: srcPath,
                                                                            project: swiftProject,
                                                                            using: .default)) {
                var passedTests = true
                // remove black space and break out lines
                let lines = content.source.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").map(String.init)
                passedTests = passedTests && XCTAssertsEqual(lines.count, 3)
                if lines.count >= 1 {
                    passedTests = passedTests && XCTAssertsTrue(lines[0].hasPrefix("// "), "Line one must be a comment")
                }
                if lines.count >= 2 {
                    passedTests = passedTests && XCTAssertsTrue(lines[1].hasPrefix("// "), "Line two must be a comment")
                }
                if lines.count >= 7 {
                    passedTests = passedTests && XCTAssertsTrue(lines[2].hasPrefix("Hello World"), "Missing inline text")
                }
                
                if !passedTests { print(content.source) }
            }
        }
    }
    
    func testDSwiftIncludeFile() {
        let swiftProject = SwiftProject(rootPath: "/")
        guard let generator = XCTAssertsNoThrow(try DynamicSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                                               console: console)) else {
            return
        }
        
        let srcPath = self.testTargetPath
            .appendingComponent("testFiles")
            .appendingComponent("dswiftIncludeFile.txt")
        
        
        
        if let content = XCTAssertsNoThrow(try generator.generateSource(from: srcPath,
                                                                        project: swiftProject,
                                                                        using: .default)) {
            var passedTests = true
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "/* *** include[file] './subFiles/dswiftSubIncludeFile.txt' Begin *** */"), 1)
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "/* *** include[file] './subFiles/dswiftSubIncludeFile.txt' End *** */"), 1)
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "This is an included dswift file"), 2)
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "/* *** include[file] './basicDSwiftFile.txt' Begin *** */"), 2)
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "/* *** include[file] './basicDSwiftFile.txt' End *** */"), 2)
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "Hello World"), 1)
            
            passedTests = passedTests && XCTAssertsEqual(content.source.countOccurrences(of: "/* *** State: Already included elsewhere *** */"), 1)
            
            if !passedTests { print(content.source) }
        }
    }
    
    func testDSwiftIncludeFolderFile() {
        let swiftProject = SwiftProject(rootPath: .root)
        guard let generator = XCTAssertsNoThrow(try DynamicSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                                               console: console)) else {
            return
        }
        
        let srcPath = self.testTargetPath
            .appendingComponent("testFiles")
            .appendingComponent("dswiftIncludeFolder.txt")
        
        if let content = XCTAssertsNoThrow(try generator.generateSource(from: srcPath,
                                                                        project: swiftProject,
                                                                        using: .default)) {
            var passedTests = true
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("/* *** include[folder] Begin ***"))
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("*** include[folder] End *** */"))
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("Path: \"./includeFolder\""))
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("*     Extension Mapping: [\"txt\": \"swift\"]"))
            
            passedTests = passedTests && XCTAssertsTrue(content.source.contains("Custom Func"))
            
            
            
            if !passedTests { print(content.source) }
        }
    }
    
    func testDSwiftIncludePackageFile() {
        let swiftProject = SwiftProject(rootPath: .root)
        guard let generator = XCTAssertsNoThrow(try DynamicSourceCodeGenerator(dswiftInfo: dswiftInfo,
                                                                               console: console)) else {
            return
        }
        
        let testFiles: [String] = [
            "dswiftIncludePackage.from.txt",
            "dswiftIncludePackage.range.txt",
            "dswiftIncludePackage.closedRange.txt",
            "dswiftIncludePackage.exact.txt",
            "dswiftIncludePackage.branch.txt",
            "dswiftIncludePackage.revision.txt"
        ]
        let testCommentIdentifiers: [String] = [
            "From: \"1.0.1\"",
            "Range: \"1.0.1\"..<\"2.0.0\"",
            "Range: \"1.0.1\"...\"1.9.9\"",
            "Exact: \"1.0.1\"",
            "Branch: \"master\"",
            "Revision: \"1f7a3c18d2e772618cbddeeca0ea51dedcfb4442\"",
        ]
        for (index, testFile) in testFiles.enumerated() {
            let srcPath = self.testTargetPath
                .appendingComponent("testFiles")
                .appendingComponent(testFile)
            
            if let content = XCTAssertsNoThrow(try generator.generateSource(from: srcPath,
                                                                            project: swiftProject,
                                                                            using: .default)) {
                var passedTests = true
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains("/* *** include[package] Begin ***"))
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains("*** include[package] End *** */"))
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains("URL: \"https://github.com/TheAngryDarling/SwiftCodeTimer.git\""))
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains(testCommentIdentifiers[index]))
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains("Package Names: [\"CodeTimer\"]"))
                
                passedTests = passedTests && XCTAssertsTrue(content.source.contains("Code Execution took"))
                
                if !passedTests { print(content.source) }
            }
        }
    }
    
    
    
    func testDSwiftCommandCaptureHelp() {
        // Only do this when testing one swift version at a time
        // because it needs visual checking

        func swiftHelpTextReplacement(_ parent: CLICommandGroup,
                                      _ argumentStartingAt: Int,
                                      _ arguments: [String],
                                      _ environment: [String: String]?,
                                      _ currentDirectory: URL?,
                                      _ standardInput: Any?,
                                      _ userInfo: [String: Any],
                                      _ stackTrace: CLIStackTrace) throws -> Int32 {
            let resp = try parent.cli.waitAndCaptureStringResponse(arguments: arguments,
                                                                   outputOptions: .captureAll,
                                                                   userInfo: userInfo,
                                                                   stackTrace: stackTrace.stacking())
            
            var workingOutput = resp.output ?? ""
            func replacing(word: String,
                           with otherWord: String,
                           in string: String,
                           range: Range<String.Index>? = nil) -> String {
                var boundEnding: String.Index? = nil
                if let idx = range?.upperBound,
                   idx != string.endIndex {
                    boundEnding = idx
                }
                var rtn = string
                var workingIdx = (range?.lowerBound ?? rtn.startIndex)
                while workingIdx != (boundEnding ?? rtn.endIndex),
                      let r = rtn.range(of: word, range: workingIdx..<(boundEnding ?? rtn.endIndex)) {
                    // Must be at start of string or white space before start of match
                    guard r.lowerBound == rtn.startIndex ||
                          rtn[rtn.index(before: r.lowerBound)].isAcceptableBeginningOfWord else {
                        workingIdx = r.upperBound
                        continue
                    }
                    // must be ending at end of string or whitespace after match
                    guard r.upperBound == rtn.endIndex ||
                          rtn[r.upperBound].isAcceptableEndingOfWord else {
                        workingIdx = r.upperBound
                        continue
                    }
                    
                    rtn.replaceSubrange(r, with: otherWord)
                    workingIdx = rtn.index(r.lowerBound, offsetBy: otherWord.count)
                    if let be = boundEnding {
                        boundEnding = rtn.index(be, offsetBy: (otherWord.count - word.count))
                    }
                }
                
                return rtn
            }
            // Find the beginning of the OPTIONS text or assume end of string
            var optionsStartingIndex = (workingOutput.range(of: "USAGE:") ?? workingOutput.range(of: "OPTIONS:"))?.lowerBound ?? workingOutput.endIndex
            workingOutput = replacing(word: "Swift",
                                      with: "Dynamic Swift",
                                      in: workingOutput,
                                      range: workingOutput.startIndex..<optionsStartingIndex)
            
            // Find the beginning of the OPTIONS text or assume end of string
            optionsStartingIndex = (workingOutput.range(of: "OPTIONS:") ?? workingOutput.range(of: "SUBCOMMANDS"))?.lowerBound ?? workingOutput.endIndex
            workingOutput = replacing(word: "swift",
                                      with: "dswift",
                                      in: workingOutput,
                                      range: workingOutput.startIndex..<optionsStartingIndex)
                   
            
            // Find the end of the SUBCOMMANDS: text or assume the beginning of the string
            let subCommandsIndex = workingOutput.range(of: "SUBCOMMANDS")?.upperBound ?? workingOutput.startIndex
            
            workingOutput = replacing(word: "swift",
                                      with: "dswift",
                                      in: workingOutput,
                                      range: subCommandsIndex..<workingOutput.endIndex)

            parent.cli.print(workingOutput)
            
            return resp.exitStatusCode
        }
        let buffer = CLICapture.STDOutputBuffer()
        let dswift = SwiftCLIWrapper.init(swiftPath: DSwiftSettings.defaultSwiftPath,
                                          outputCapturing: .capture(using: buffer),
                                          helpActionHandler: swiftHelpTextReplacement)
        
        dswift.createCommand(command: "help",
                             actionHandler: swiftHelpTextReplacement)
        
        try! dswift.execute(["-h"])
        //try! dswift.execute(["help", "run"])

    }
    
    /// Run the test app for the given swift command
    /// - Parameter generateSwiftCommandArgs: Callback method used to generate the dswift arguments used setup the swift command.  This callback provides the path to the current project directory.  When mapping for containers, the project directory must be mapped as well as the NSTemporaryDirectory()
    func _testDSwiftCommands(_ generateSwiftCommandArgs: (_ projectDir: FSPath) -> [String] = { _ in return [] }) {
        
        
        var appName: String = "TestSwiftApp"
        let fileManager = FileManager.default
        let tempFolderBase = FSPath.tempDir
        var tmpFolder = tempFolderBase.appendingComponent(appName)
        defer {
            try? tmpFolder.remove(using: fileManager)
        }
        
        
        if tmpFolder.exists(using: fileManager) {
            var idx: Int = 1
            repeat {
                tmpFolder = tempFolderBase.appendingComponent("\(appName)\(idx)")
                idx += 1
            } while tmpFolder.exists(using: fileManager)
            // Update appName to be 'TestSwiftApp#'
            appName = tmpFolder.lastComponent
        }
        
        var workingSwiftCommand = generateSwiftCommandArgs(tmpFolder)
        workingSwiftCommand.insert("dswift", at: 0)
        
        let outputBuffer = CLICapture.STDOutputBuffer()
        do {
            if !tmpFolder.exists(using: fileManager) {
                try tmpFolder.createDirectory(withIntermediateDirectories: true,
                                              using: fileManager)
            }
            
            fileManager.changeCurrentDirectoryPath(tmpFolder.string)
            guard DSwiftApp.execute(outputCapturing: .capture(using: outputBuffer),
                                    arguments: workingSwiftCommand + [
                                                "package",
                                                "init",
                                                "--type",
                                                "executable"]) == 0 else {
                var msg: String = ""
                let dta = outputBuffer.readBuffer()
                if let path = String(data: dta, encoding: .utf8) {
                    msg = path
                }
                XCTFail("Failed to create new package:\n\(msg)")
                return
            }
            
            /// Empty buffer between each call
            outputBuffer.empty()
            
            // copy test code here
            let sourceFolder = tmpFolder.appendingComponent("Sources")
            let appSourceFolder = sourceFolder.appendingComponent(appName)
            let mainSwiftFileV5_7 = appSourceFolder.appendingComponent("\(appName).swift")
            let mainSwiftFileLTV5_7 = appSourceFolder.appendingComponent("main.swift")
            let mainSwiftFile: FSPath
            if mainSwiftFileLTV5_7.exists(using: fileManager) {
                mainSwiftFile = mainSwiftFileLTV5_7
            } else if mainSwiftFileV5_7.exists(using: fileManager) {
                mainSwiftFile = mainSwiftFileV5_7
            } else {
                XCTFail("Unable to identify Test App's main file")
                return
            }
            do {
                try mainSwiftFile.remove(using: fileManager)
            } catch {
                XCTFail("Failed to remove default main(\(mainSwiftFile.string): \(error)")
                return
            }
            
            let srcTestApp = FSPath(self.testTargetURL.appendingPathComponent("TestSwiftApp").path)
            do {
                let testAppMain = srcTestApp.appendingComponent("testapp_main._swift")
                try testAppMain.copy(to: mainSwiftFile, using: fileManager)
            } catch {
                XCTFail("Failed to copy test main to sources folder: \(error)")
                return
            }
            
            do {
                let dswiftFile = srcTestApp.appendingComponent("testapp_dswift._dswift")
                try dswiftFile.copy(to: appSourceFolder.appendingComponent("testapp_dswift.dswift"),
                                           using: fileManager)
            } catch {
                XCTFail("Failed to copy primary dswift file: \(error)")
                return
            }
            
            do {
                let includeFile = srcTestApp.appendingComponent("included.file.dswiftInclude")
                try includeFile.copy(to: appSourceFolder.appendingComponent("included.file.dswiftInclude"),
                                     using: fileManager)
            } catch {
                XCTFail("Failed to copy primary included file: \(error)")
                return
            }
            
            do {
                let includeFolder = srcTestApp.appendingComponent("includeFolder")
                try includeFolder.copy(to: appSourceFolder.appendingComponent("includeFolder"),
                                       using: fileManager)
            } catch {
                XCTFail("Failed to copy included folder: \(error)")
                return
            }
            
            
            guard DSwiftApp.execute(outputCapturing: .capture(using: outputBuffer),
                                    arguments: workingSwiftCommand + [
                                                "build",
                                                "-Xswiftc",
                                                "-DDOCKER_BUILD"]) == 0 else {
                var msg: String = ""
                let dta = outputBuffer.readBuffer()
                if let path = String(data: dta, encoding: .utf8) {
                    msg = path
                }
                XCTFail("Failed to build package:\n\(msg)")
                return
            }
            
            let generatedSwiftFile = appSourceFolder.appendingComponent("testapp_dswift.swift")
            XCTAssertTrue(generatedSwiftFile.exists(using: fileManager),
                          "Generated swift file '\(generatedSwiftFile.string)' does not exist")
            
            /// Empty buffer between each call
            outputBuffer.empty()
            
            guard DSwiftApp.execute(outputCapturing: .capture(using: outputBuffer),
                                   arguments: workingSwiftCommand + ["run",
                                                                     appName]) == 0 else {
                var msg: String = ""
                let dta = outputBuffer.readBuffer()
                if let path = String(data: dta, encoding: .utf8) {
                    msg = path
                }
                XCTFail("Failed to run test app:\n\(msg)")
                return
            }
            
            guard let out = String(data: outputBuffer.out.readBuffer(), encoding: .utf8) else {
                XCTFail("No Output from test app")
                return
            }
            
            XCTAssertTrue(out.contains("Hello World"))
            XCTAssertTrue(out.contains("Code Execution took"))
            
            XCTAssertTrue(out.contains("This is content from the included file"))
            XCTAssertTrue(out.contains("This is content from the included folder file"))
            
            
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testSwiftCommands() {
        _testDSwiftCommands()
    }
    
    func testDSwiftCommands() {
        
        _testDSwiftCommands() { path in
            return ["---",
                    "--swiftPath",
                    DSwiftSettings.defaultSwiftPath.string,
                    "---"]
        }
    }
    
    func testDockerDSwiftCommands() {
        
        struct UserInfo {
            public let userId: Int
            public let userName: String
            public let groupId: Int
            public let groupName: String
        }
        
        #if os(Windows)
        // this section is currently not supported
        let pathSeperator: Character = ";"
        let dirSeperator: String = "\\"
        let dockerCommand: String = "docker.exe"
        #else
        let pathSeperator: Character = ":"
        let dirSeperator: String = "/"
        let dockerCommand: String = "docker"
        #endif
        var paths = ProcessInfo.processInfo.environment["PATH", default: ""].split(separator: pathSeperator).map(String.init)
        
        if dirSeperator == "/" && !paths.contains("/usr/local/bin") {
            paths.append("/usr/local/bin")
        }
        
        var dockerPath: String? = nil
        let fileManager = FileManager.default
        
        for var path in paths {
            if path.hasSuffix(dirSeperator) {
                path.removeLast()
            }
            let testDockerPath = String(path + dirSeperator + dockerCommand)
            if fileManager.fileExists(atPath: testDockerPath),
               fileManager.isExecutableFile(atPath: testDockerPath) {
                dockerPath = testDockerPath
            }
            
        }
        
        guard let dp = dockerPath else {
            print("WARNING: Unable to test testDockerDSwiftCommands because Docker not found")
            return
        }
        
        // Test if docker is running
        let dockerStatusProcess = Process()
        // setup path to docker executable
        dockerStatusProcess.executable = URL(fileURLWithPath: dp)
        // add arguments (simple command to test if it fails)
        dockerStatusProcess.arguments = ["stats", "--no-stream"]
        // setup pipe to capture all output and stop if from going
        // to the stdout.  We will ignore the output
        let dockerStatusProcessNullPipe = Pipe()
        dockerStatusProcess.standardOutput = dockerStatusProcessNullPipe
        dockerStatusProcess.standardError = dockerStatusProcessNullPipe
        // Run the executable
        guard XCTAssertsNoThrow(try dockerStatusProcess.execute()) else {
            return
        }
        // wait for it to finish
        dockerStatusProcess.waitUntilExit()
        // make sure it ran successfully.  If failed
        // lets fail the test
        guard dockerStatusProcess.terminationStatus == 0 else {
            XCTFail("Docker not running")
            return
        }
        // Lets try and get the current user id number
        // for mapping into docker
        let userId = IDCLI.getUserID()
        
        if userId == nil {
            print("WARNING: Unable to get current user id")
        }
        
        _testDSwiftCommands() { path in
            /*
             Required Volumes to map into docker with the same as real path
                1: FSPath.tempDir (And if is symlink also real path)
                    This location is used to create sub folders to generate swift
                2: Path to project or a parent folder of the project
            */
            
            // Setup dswift swift command begin
            var rtn: [String] = ["---",
                                 "--swiftCommandBegin"]
            
            // Setup Docker Swift Container Command start
            rtn.append(contentsOf: [
                                 // Path to docker
                                 dp,
                                 // run container
                                 "run",
                                 // name container dswift-(folder name)-(random characters)
                                 "--name",
                                 "dswift-\(path.lastComponent)-\(String.randomAlphaNumericString(count: 8))",
                                 // remove container after exit
                                 "--rm",
                                 "-t",
                                 // setup extra privileges
                                 "--cap-add=SYS_PTRACE",
                                 "--security-opt",
                                 "seccomp=unconfined"
                                 ])
            
            // Setup Mapped Volumes
            var mappedDirs: [FSPath] = []
            
            func mapPath(_ pth: FSPath) {
                
                // see if path is already mapped or is a child path of a previously
                // mapepd volume
                if !mappedDirs.contains(pth) &&
                   !mappedDirs.contains(where: { return pth.isChildPath(of: $0) }) {
                    // Map path into the docker container
                    rtn.append(contentsOf: ["-v",
                                            "\(pth.string):\(pth.string)"])
                    // Save the mapped path for reference
                    // for any additional paths to map
                    mappedDirs.append(pth)
                    
                }
               
                // safe the current directory
                let oldDir = fileManager.currentDirectoryPath
                // change the current directory to the pth directory
                fileManager.changeCurrentDirectoryPath(pth.string)
                // check to see if path was symbolic link
                if fileManager.currentDirectoryPath != pth.string {
                    // Path was a symbolic link,  mapping real path into docker container
                    let realPath = FSPath(fileManager.currentDirectoryPath)
                    // make sure the real path is not a previously mapped path or
                    // a child path of a previously mapped path
                    if !mappedDirs.contains(realPath) &&
                       !mappedDirs.contains(where: { return realPath.isChildPath(of: $0) }) {
                        // Map the path into the docker container
                        rtn.append(contentsOf: ["-v",
                                                "\(realPath.string):\(realPath.string)"])
                        // Save the mapped path for reference
                        // for any additional paths to map
                        mappedDirs.append(realPath)
                    }
                }
                // change the current directory back to original
                fileManager.changeCurrentDirectoryPath(oldDir)
                
            }
            
            // Map temp folder
            mapPath(FSPath.tempDir)
            // Map path to test project
            mapPath(path)
            
            if let uid = userId {
                // add docker arguments to specify the
                // user id to use instead of root(0)
                //
                // This helps when dockerd is running
                // in root but you want any files that the
                // container generates to be accessable by
                // the current user
                rtn.append(contentsOf: [
                    "-u",
                    "\(uid)"
                ])
            }
            // Add Docker Image/tag to use for the container
            rtn.append("swift:4.0")
            // Add the command to execute within the docker container
            rtn.append("swift")
            
            // append ending dswift arguments
            rtn.append(contentsOf: ["--swiftCommandEnd",
                                    "---"])
            return rtn
        }
    }

    static var allTests = [
        ("testPaths", testPaths),
        ("testJSONCommentBlocks", testJSONCommentBlocks),
        ("testEncodeDecodeDefaultSettings", testEncodeDecodeDefaultSettings),
        ("testLicenseText", testLicenseText),
        ("testReadMeFile", testReadMeFile),
        ("testStaticStringFiles", testStaticStringFiles),
        ("testStaticBinaryFiles", testStaticBinaryFiles),
        ("testDSwiftBasic", testDSwiftBasic),
        ("testDSwiftIncludeFile", testDSwiftIncludeFile),
        ("testDSwiftIncludeFolderFile", testDSwiftIncludeFolderFile),
        ("testDSwiftIncludePackageFile", testDSwiftIncludePackageFile),
        ("testDSwiftCommandCaptureHelp", testDSwiftCommandCaptureHelp),
        ("testSwiftCommands", testSwiftCommands),
        ("testDSwiftCommands", testDSwiftCommands),
        ("testDockerDSwiftCommands", testDockerDSwiftCommands)
    ]
}


