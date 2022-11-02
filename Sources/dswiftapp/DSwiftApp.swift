//
//  DSwiftApp.swift
//
//
//  Created by Tyler Anger on 2022-04-20.
//

import Foundation
import dswiftlib
import VersionKit
import XcodeProj
import RegEx
import CLIWrapper
import struct CLICapture.CodeStackTrace
import PathHelpers

public enum DSwiftApp {
    
    public static let dSwiftVersion: Version.SingleVersion = "2.0.2"
    public static let dSwiftModuleName: String = "Dynamic Swift"
    public static let dSwiftURL: String = "https://github.com/TheAngryDarling/dswift"
    
    public static func execute(outputCapturing: CLIWrapper.STDOutputCapturing? = nil,
                               arguments: [String] = ProcessInfo.processInfo.arguments,
                               environment: [String: String] = ProcessInfo.processInfo.environment) -> Int32 {
        var arguments = arguments
        
        #if ENABLE_ENV_USER_DETAILS
        // tells XcodeProjectBuilders.UserDetails to check env for REAL_USER_NAME and REAL_DISPLAY_NAME
        XcodeProjectBuilders.UserDetails.supportEnvUserName = true
        #endif
        
        let dSwiftAppName: String = arguments.first!.components(separatedBy: "/").last!
        var dSwiftTempDir: FSPath = FSPath.tempDir
        let dSwiftSettingsFilePath: String = "~/.\(dSwiftAppName).config"
        
        let beginDSwiftSection: String = "---"
        let endDSwiftSection: String = "---"

        var supportsHelpCommand: Bool = false

        var console = Console.default
        
        /// List of dswift parameters
        var dswiftParams: [String] = []
        /// List of swift parameters to pass onto swift
        var swiftParams: [String] = []
        /// Indictor if we are in the dswift parameter section
        var isInDSwiftParamSection: Bool = false


        arguments.removeFirst() //First parameter is the application path

        // Moved search for --dswift[verbose|debug]
        // before seperation of dswift params and swift params
        // added --dswiftSetTempDir to the list of
        var isDebugOutput = false
        var isVerboseOutput = false
        var checkDSwiftParameters = 0
        // parse out any --dswift parameters  out of argument list
        while checkDSwiftParameters < arguments.count {
            let paramLowered = arguments[checkDSwiftParameters].lowercased()
            switch paramLowered {
                case "--dswiftdebug":
                    // set flag that will tell console object to log debug logs
                    isDebugOutput = true
                    arguments.remove(at: checkDSwiftParameters)
                case "--dswiftverbose":
                    // set flag that will tell console object to log verbose logs
                    isVerboseOutput = true
                    arguments.remove(at: checkDSwiftParameters)
                case "--dswiftsettempdir":
                    // change the working temp directory
                    guard checkDSwiftParameters < arguments.count - 1 else {
                        console.printError("Missing new temp directory")
                        return 1
                    }
                    // remove the --dswiftSetTempDir parameter
                    arguments.remove(at: checkDSwiftParameters)
                    let newTempDir = arguments[checkDSwiftParameters]
                    var isDir: Bool = false
                    guard FileManager.default.fileExists(atPath: newTempDir, isDirectory: &isDir) else {
                        console.printError("New temp directory '\(newTempDir)' does not exist")
                        return 1
                    }
                    guard isDir else {
                        console.printError("'\(newTempDir)' is not a folder")
                        return 1
                    }
                    dSwiftTempDir = FSPath(newTempDir)
                    // remove the actual path parameter
                    arguments.remove(at: checkDSwiftParameters)
                default:
                    // move index to next argument
                    checkDSwiftParameters += 1
            }
            
        }
        
        // Provides a way for scripts to get the path used in dswift for the temp dir
        // helpfull when using --swiftCommand[Begin|End] when mapping folders
        if arguments.contains(where: { return $0.lowercased() == "--dswifttempdir" }) {
            console.print(dSwiftTempDir.string)
            return 0
        }

        var settings: DSwiftSettings = {
            let settingsPath = NSString(string: dSwiftSettingsFilePath).standardizingPath
            guard FileManager.default.fileExists(atPath: settingsPath) else {
                return DSwiftSettings()
            }
            do {
                return try DSwiftSettings.init(fromPath: settingsPath)
            } catch {
                console.printError("There was an error while loading dswift settings from '\(dSwiftSettingsFilePath)'\n\(error)")
                console.printVerbose("\(error)")
                return DSwiftSettings()
            }
        }()
        
        
        #if NO_DSWIFT_PARAMS
            // If no dswift paramters supported, all parameters must be for swift
            swiftParams = arguments
        #else

            for (i, p) in arguments.enumerated() {
                if i == 0 && p == beginDSwiftSection { isInDSwiftParamSection = true }
                else if (i > 0 && p == endDSwiftSection) { isInDSwiftParamSection = false }
                else if isInDSwiftParamSection { dswiftParams.append(p) }
                else { swiftParams.append(p) }
            }
        
            var hasSwiftPath: Bool = false
            if let idx = dswiftParams.firstIndex(of: "--swiftPath") {
                guard idx < dswiftParams.count - 1 else {
                    console.printError("Missing '--swiftPath' argument value")
                    return 1
                }
                hasSwiftPath = true
                settings.swiftCommand = .init(FSPath(dswiftParams[idx + 1]))
            }
        
            if let cmdBeginAfter = dswiftParams.firstIndex(of: "--swiftCommandBegin") {
                guard let cmdEndBefore = dswiftParams.firstIndex(of: "--swiftCommandEnd") else {
                    console.printError("Missing '--swiftCommandEnd' argument")
                    return 1
                }
                guard cmdBeginAfter < cmdEndBefore else {
                    console.printError("'--swiftCommandEnd' argument must be after '--swiftCommandBegin' argument")
                    return 1
                }
                
                var commands = Array<String>(dswiftParams[dswiftParams.index(after: cmdBeginAfter)..<cmdEndBefore])
                guard commands.count > 0 else {
                    console.printError("No arguemnts found for swift command")
                    return 1
                }
                let exec = commands[0]
                commands.remove(at: 0)
                if hasSwiftPath {
                    console.printError("WARNING: '--swiftPath' and '--swiftCommandBegin'/'--swiftCommandEnd' arguments both set.  Using '--swiftCommandBegin'/'--swiftCommandEnd'")
                }
                settings.swiftCommand = .init(executablePath: exec, arguments: commands)
            }

        #endif


        /// Gets the current project path. Default is FileManager.default.currentDirectoryPath unless the --package-path flag has been passed along
        let currentProjectPath: String = {
            var rtn: String = FileManager.default.currentDirectoryPath
            if let idx = swiftParams.firstIndex(of: "--package-path"), idx < (swiftParams.count - 1) {
                FileManager.default.changeCurrentDirectoryPath(swiftParams[idx + 1])
                let newDir = FileManager.default.currentDirectoryPath
                FileManager.default.changeCurrentDirectoryPath(rtn)
                rtn = newDir
            }
            return rtn
        }()

        
        func swiftHelpAction(parent: CLICommandGroup,
                             argumentStartingAt: Int,
                             arguments: [String],
                             environment: [String: String]?,
                             currentDirectory: URL?,
                             withMessage message: String? = nil,
                             userInfo: [String: Any],
                             stackTrace: CodeStackTrace) throws -> Int32 {
            if let m = message {
                console.print(m)
            }
            var arguments = arguments
            let subCommands = ["package", "build", "rebuild", "test", "run", "help"]
            guard arguments.count > 0 &&
                  subCommands.contains(arguments[0].lowercased()) else {
                // Do default help here
                      console.print("OVERVIEW: \(dSwiftModuleName) compiler")
                      console.print("")
                      console.print("USAGE: \(dSwiftAppName) [\(dSwiftAppName) OPTIONS] <subcommand>")
                      console.print("")
                      console.print("SUBCOMMANDS (\(dSwiftAppName) <subcommand> [arguments]):")
                      console.print("  build:     SwiftPM - Build sources into binary products")
                      console.print("  rebuild:   SwiftPM - Rebuilds sources into binary products")
                      console.print("  package:   SwiftPM - Perform operations on Swift packages")
                      console.print("  run:       SwiftPM - Build and run an executable product")
                      console.print("  test:      SwiftPM - Build and run tests")
                      if supportsHelpCommand {
                          console.print("")
                          console.print("  Use \"\(dSwiftAppName) help <subcommand>\" for more information about a subcommand")
                      }
                      console.print("")
                      console.print("\(dSwiftAppName) OPTIONS:")
                      console.print("\(dSwiftAppName) options must be encapsulated within '\(beginDSwiftSection)' ... '\(endDSwiftSection)'")
                      console.print("  --swiftPath:      Specify the path to the swift executable to use")
                      console.print("  --swiftCommandBegin/--swiftCommandEnd:")
                      console.print("    Specify the executable and arguments needed to run swift.  Executable and arguments must fall between the begin and end parameters (This is useful for executing swift within a container)")
                      console.print("")
                      console.print("OTHER:")
                      console.print("  --dswiftVerbose:      Allow \(dSwiftAppName) verbose logging")
                      console.print("  --dswiftDebug:        Allow \(dSwiftAppName) debug logging")
                      console.print("  --dswiftTempDir:      Returns the temp directory used by \(dSwiftAppName).  This parameter will not process any dswift or swift commands")
                      console.print("  --dswiftSetTempDir:   Sets the directory used for temporary files")
                
                return 0
            }
            
            let helpArguments = ["help", "-h", "--h", "-help", "--help"]
            if !arguments.contains(where: { return helpArguments.contains($0.lowercased()) }) {
                arguments.append("-help")
            }
            
            
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
                                      with: dSwiftModuleName,
                                      in: workingOutput,
                                      range: workingOutput.startIndex..<optionsStartingIndex)
            
            // Find the beginning of the OPTIONS text or assume end of string
            optionsStartingIndex = (workingOutput.range(of: "OPTIONS:") ?? workingOutput.range(of: "SUBCOMMANDS"))?.lowerBound ?? workingOutput.endIndex
            workingOutput = replacing(word: "swift",
                                      with: dSwiftAppName,
                                      in: workingOutput,
                                      range: workingOutput.startIndex..<optionsStartingIndex)
                   
            
            // Find the end of the SUBCOMMANDS: text or assume the beginning of the string
            let subCommandsIndex = workingOutput.range(of: "SUBCOMMANDS")?.upperBound ?? workingOutput.startIndex
            
            workingOutput = replacing(word: "swift",
                                      with: dSwiftAppName,
                                      in: workingOutput,
                                      range: subCommandsIndex..<workingOutput.endIndex)
            
            console.print(workingOutput)
            
            var ret = resp.exitStatusCode
            if message != nil && ret == 0 {
                ret = 1
            }
            return ret
        }


        let swiftWrapper = SwiftCLIWrapper.init(swiftCommand: settings.swiftCommand,
                                                outputCapturing: outputCapturing,
                                                helpActionHandler: swiftHelpAction)

        // Create new console instance using settings and cli wrapper
        // We use cli wrapper to ensure that all output
        // is synchronized as well as can be captured
        // by any output capturing buffers for debuging
        // purposes
        console = Console(canPrintVerbose: settings.isVerbose || isVerboseOutput,
                          canPrintDebug: isDebugOutput,
                          printOut: {
                                swiftWrapper.cli.print($0,
                                                       terminator: "")
                          },
                          printErr: {
                                swiftWrapper.cli.printError($0,
                                                            terminator: "")
                          })

        func flushOutput() {
            
            fflush(stdout)
            fsync(STDOUT_FILENO)
            fflush(stderr)
            fsync(STDERR_FILENO)
            swiftWrapper.cli.outputLock.lockingFor {
                // wait for all outputs to flush
                fflush(stdout)
                fsync(STDOUT_FILENO)
                fflush(stderr)
                fsync(STDERR_FILENO)
            }
        }

        // Grab root help screen
        if let helpScreen = try? swiftWrapper.cli.waitAndCaptureStringResponse(arguments: ["-help"]) {
            // See if Swift supports 'swift help ...'
            if helpScreen.output?.contains("swift help <") ?? false {
                supportsHelpCommand = true
                /// Add replacement help command
                swiftWrapper.createCommand(command: "help") {
                    (_ parent: CLICommandGroup,
                     _ argumentStartingAt: Int,
                     _ arguments: [String],
                     _ environment: [String: String]?,
                     _ currentDirectory: URL?,
                     _ standardInput: Any?,
                     _ userInfo: [String: Any],
                     _ stackTrace: CodeStackTrace) throws -> Int32 in
                    
                    return try swiftHelpAction(parent: parent,
                                               argumentStartingAt: argumentStartingAt,
                                               arguments: arguments,
                                               environment: environment,
                                               currentDirectory: currentDirectory,
                                               userInfo: userInfo,
                                               stackTrace: stackTrace.stacking())
                }
                
            }
        }
        
        let swiftVersion: Version.SingleVersion
        do {
            swiftVersion = try swiftWrapper.getVersion()
        } catch {
            console.printError("Unable to get Swift Version: \(error)")
            flushOutput()
            return 1
        }
        

        let commands: Commands
        
        do {
            // Setup all wrapper commands
            commands = try Commands.init(dswiftInfo: DSwiftInfo(moduleName: dSwiftModuleName,
                                                                appName: dSwiftAppName,
                                                                url: dSwiftURL,
                                                                version: dSwiftVersion),
                                         dSwiftSettingsFilePath: dSwiftSettingsFilePath,
                                         currentProjectPath: FSPath(currentProjectPath),
                                         beginDSwiftSection: beginDSwiftSection,
                                         endDSwiftSection:  endDSwiftSection,
                                         settings: settings,
                                         swiftWrapper: swiftWrapper,
                                         swiftVersion: swiftVersion,
                                         tempDir: dSwiftTempDir,
                                         console: console)
        } catch {
            console.printError("Unable to load commands: \(error)")
            flushOutput()
            return 1
        }

        // Do this to get rid of warning of 'commands' being unused
        _ = commands.supportsXcodeProjGen

        

        //console.print("Running with Swift '\(swiftVersion)' \(swiftParams.joined(separator: " "))")
        do {
            guard let ret = try swiftWrapper.executeIfWrapped(swiftParams) else {
                var msg: String = "Missing SUBCOMMAND"
                if swiftParams.count > 0 {
                    msg = "Invalid arguments \(swiftParams.map{ return "'\($0)'" }.joined(separator: ", "))"
                }
                try swiftWrapper.displayUsage(withMessage: msg)
                
                flushOutput()
                return 1
            }
            flushOutput()
            return ret
        } catch {
            console.printError("Error: \(error)")
            flushOutput()
            return 1
        }
    }
}
