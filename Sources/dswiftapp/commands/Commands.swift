//
//  Commands.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import VersionKit
import dswiftlib
import PathHelpers

import CLIWrapper

/// Namespace where all the different commands are stored
public struct Commands {
    /// Information about the current version of DSwift
    public let dswiftInfo: DSwiftInfo
    /// The Application Display Name
    public var dSwiftModuleName: String { return self.dswiftInfo.moduleName }
    /// The application file name (name only, not path)
    public var dSwiftAppName: String { return self.dswiftInfo.appName }
    /// The URL to the application Site
    public var dSwiftURL: String { return self.dswiftInfo.url }
    /// The current version of the application
    public var dSwiftVersion: Version.SingleVersion { return self.dswiftInfo.version }
    /// The Path to the DSwift Settings Config file
    public let dSwiftSettingsFilePath: String
    /// The Path to the project
    public let currentProjectPath: FSPath
    /// DSwift argument denoting the beginning of DSwift flags
    public let beginDSwiftSection: String
    /// DSwift arguemnt denoting the ending of DSwift flags
    public let endDSwiftSection:  String
    /// DSwift Settings
    public let settings: DSwiftSettings
    /// Group of Generators being used
    public private(set) var generator: GroupGenerator
    /// Method used to execute commands
    public let swiftWrapper: SwiftCLIWrapper
    /// Console object used to write to output
    public let console: Console
    /// Indicator if the current version of Swift supports generating Xcode Project files
    public fileprivate(set) var supportsXcodeProjGen: Bool = false
    /// The version of swift currently being used
    public let swiftVersion: Version.SingleVersion
    
    /// Create new Commands object
    /// - Parameters:
    ///   - dswiftInfo: Information about the current version of DSwift
    ///   - dSwiftSettingsFilePath: The Path to the DSwift Settings Config file
    ///   - currentProjectPath: The Path to the project
    ///   - beginDSwiftSection: DSwift argument denoting the beginning of DSwift flags
    ///   - endDSwiftSection: DSwift arguemnt denoting the ending of DSwift flags
    ///   - settings: DSwift Settings Object
    ///   - generator: Group of Generators being used
    ///   - swiftWrapper: Method used to execute commands
    ///   - swiftVersion: The version of swift currently being used
    ///   - console: The object used to print to the console
    public init(dswiftInfo: DSwiftInfo,
                dSwiftSettingsFilePath: String,
                currentProjectPath: FSPath,
                beginDSwiftSection: String,
                endDSwiftSection:  String,
                settings: DSwiftSettings,
                generator: GroupGenerator,
                swiftWrapper: SwiftCLIWrapper,
                swiftVersion: Version.SingleVersion,
                console: Console = .null) {
        self.dswiftInfo = dswiftInfo
        self.dSwiftSettingsFilePath = dSwiftSettingsFilePath
        self.currentProjectPath = currentProjectPath
        self.beginDSwiftSection = beginDSwiftSection
        self.endDSwiftSection = endDSwiftSection
        self.settings = settings
        self.generator = generator
        
        self.swiftWrapper = swiftWrapper
        self.swiftVersion = swiftVersion
        self.console = console
        
        swiftWrapper.createCommand(command: "--config",
                                   actionHandler: self.commandConfig)
        swiftWrapper.createPreCLICommand(regEx: try! .init("\\-{1,2}version"),
                                         actionHandler: self.commandVersion)
        swiftWrapper.createPreCLICommand(command: "build",
                                     caseSensitive: false,
                                     actionHandler: self.commandDSwiftBuild)
        swiftWrapper.createPreCLICommand(command: "rebuild",
                                     caseSensitive: false,
                                     actionHandler: self.commandDSwiftBuild)
        swiftWrapper.createPreCLICommand(command: "test",
                                     caseSensitive: false,
                                     actionHandler: self.commandDSwiftBuild)
        swiftWrapper.createPreCLICommand(command: "run",
                                     caseSensitive: false,
                                     actionHandler: self.commandDSwiftBuild)
        swiftWrapper.createCommand(command: "xcodebuild",
                                   caseSensitive: false,
                                   actionHandler: self.commandXcodeDSwiftBuild)
        
        let package = swiftWrapper.createCommandGroup(command: "package",
                                                      caseSensitive: false,
                                                      helpAction: .useParentAction,
                                                      defaultAction: CLIPassthroughAction.shared)
        
        
        // package init
        package.createWrappedCommand(command: "init",
                                     caseSensitive: false,
                                     passthroughOptions: .all,
                                     preActionHandler: self.commandPackageInitPreSwift,
                                     postActionHandler: self.commandPackageInitPostSwift)
        // package clean
        package.createWrappedCommand(command: "clean",
                                     caseSensitive: false,
                                     passthroughOptions: .none,
                                     preActionHandler: self.cleanResetDSwiftBuildsPreSwift,
                                     postActionHandler: self.cleanResetDSwiftBuildsPostSwift)
        // package reset
        package.createWrappedCommand(command: "reset",
                                    caseSensitive: false,
                                     passthroughOptions: .none,
                                     preActionHandler: self.cleanResetDSwiftBuildsPreSwift,
                                     postActionHandler: self.cleanResetDSwiftBuildsPostSwift)
        
        // get help screen to determine which commands are available
        if let packageHelp = try? swiftWrapper.cli.waitAndCaptureStringResponse(arguments: ["package", "-help"]) {
            
           if (packageHelp.output?.contains("generate-xcodeproj") ?? false) {
            
                self.supportsXcodeProjGen = true
                
                // package update
                package.createPostCLICommand(command: "update",
                                                  caseSensitive: false,
                                                  passthroughOptions: .all,
                                                  actionHandler: self.commandPackageUpdate)
                
                // package generate-xcodeproj
                package.createPostCLICommand(command: "generate-xcodeproj",
                                             caseSensitive: false,
                                             passthroughOptions: .all,
                                             actionHandler: self.commandPackageGenXcodeProj)
            }
            
            if packageHelp.output?.contains("generate-completion-script") ?? false {
                // generate-completion-script
                package.createPostCLICommand(command: "generate-completion-script",
                                             caseSensitive: false,
                                             passthroughOptions: .none,
                                             actionHandler: self.commandGenerateCompletionScript)
                
                // Old way of getting completion script
                package.createCommand(command: "install-completion-script",
                                      caseSensitive: false,
                                      actionHandler: self.commandPackageInstallAutoScriptGenCompletionScript)
            }
            if packageHelp.output?.contains("completion-tool") ?? false {
                
                // New way of getting completion script
                package.createCommand(command: "install-completion-script",
                                      caseSensitive: false,
                                      actionHandler: self.commandPackageInstallAutoScriptCompletionTool)
                
                // completion-tool
                let completionTool = package.createCommandGroup(command: "completion-tool",
                                                                helpAction: .useParentAction)
                
                // must test for supported completion tools here
                if packageHelp.output?.contains("generate-bash-script") ?? false {
                    completionTool.createPostCLICommand(command: "generate-bash-script",
                                                 caseSensitive: false,
                                                 passthroughOptions: .none,
                                                 actionHandler: self.commandCompletionToolsBash)
                }
                if packageHelp.output?.contains("generate-zsh-script") ?? false {
                    completionTool.createPostCLICommand(command: "generate-zsh-script",
                                                 caseSensitive: false,
                                                 passthroughOptions: .none,
                                                 actionHandler: self.commandCompletionToolsZSH)
                }
                if packageHelp.output?.contains("generate-fish-script") ?? false {
                    package.createPostCLICommand(command: "generate-fish-script",
                                                 caseSensitive: false,
                                                 passthroughOptions: .none,
                                                 actionHandler: self.commandCompletionToolsFish)
                }
            }
            
            
            
        }
        
        
        
    }
    
    /// Create new Commands object
    /// - Parameters:
    ///   - dswiftInfo: Information about the current version of DSwift
    ///   - dSwiftSettingsFilePath: The Path to the DSwift Settings Config file
    ///   - currentProjectPath: The Path to the project
    ///   - beginDSwiftSection: DSwift argument denoting the beginning of DSwift flags
    ///   - endDSwiftSection: DSwift arguemnt denoting the ending of DSwift flags
    ///   - settings: DSwift Settings Object
    ///   - swiftWrapper: Method used to execute commands
    ///   - swiftVersion: The version of swift currently being used
    ///   - tempDir: The location for temporary file storage
    ///   - console: The object used to print to the console
    public init(dswiftInfo: DSwiftInfo,
                dSwiftSettingsFilePath: String,
                currentProjectPath: FSPath,
                beginDSwiftSection: String,
                endDSwiftSection:  String,
                settings: DSwiftSettings,
                swiftWrapper: SwiftCLIWrapper,
                swiftVersion: Version.SingleVersion,
                tempDir: FSPath = FSPath.tempDir,
                console: Console = .null) throws {
        
        self.init(dswiftInfo: dswiftInfo,
                  dSwiftSettingsFilePath: dSwiftSettingsFilePath,
                  currentProjectPath: currentProjectPath,
                  beginDSwiftSection: beginDSwiftSection,
                  endDSwiftSection:  endDSwiftSection,
                  settings: settings,
                  generator: try GroupGenerator.init(swiftCommand: settings.swiftCommand,
                                                     dswiftInfo: dswiftInfo,
                                                     tempDir: tempDir,
                                                     console: console),
                  swiftWrapper: swiftWrapper,
                  swiftVersion: swiftVersion,
                  console: console)
        
    }

    /// Finds the path to the given command or returns nil if the command is not found
    internal static func which(_ command: String) -> String? {
        #if os(Windows)
        let dirSeperator: String = "\\"
        let pathSeperator: Character = ";"
        #else
        let dirSeperator: String = "/"
        let pathSeperator: Character = ":"
        #endif
        
        let pathsStr = ProcessInfo.processInfo.environment["PATH"] ?? ""
        
        let paths = pathsStr.split(separator: pathSeperator).map(String.init)
        for var path in paths {
            // If we have a marker for the current directory lets change to full path
            if path == "." || path == ".\(dirSeperator)" { path = FileManager.default.currentDirectoryPath }
            // Make sure path exists
            guard FileManager.default.fileExists(atPath: path) else { continue}
            
            // Build url to the command within the path
            let cmdURL = URL(fileURLWithPath: path).resolvingSymlinksInPath().appendingPathComponent(command)
            
            // Make sure the full command path exists
            guard FileManager.default.fileExists(atPath: cmdURL.path) else { continue }
            // Make sure that the command is executable
            guard FileManager.default.isExecutableFile(atPath: cmdURL.path) else { continue }
            
            return cmdURL.path
            
        }
        return nil
    }
    /// Finds the path to the given command or returns nil if the command is not found
    internal func which(_ command: String) -> String? {
        return Commands.which(command)
    }
    
}
