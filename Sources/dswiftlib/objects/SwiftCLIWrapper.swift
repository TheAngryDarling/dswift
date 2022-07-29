//
//  SwiftCLIWrapper.swift
//  dswiftlib
//  
//
//  Created by Tyler Anger on 2022-03-13.
//

import Foundation
import Dispatch
import RegEx
import VersionKit
import CLIWrapper
import struct CLICapture.CLIStackTrace
import PathHelpers


public class SwiftCLIWrapper: CLIWrapper {
    
    public enum SwiftErrors: Swift.Error, CustomStringConvertible {
        case unableToFindVersionPattern(in: String)
        case invalidVersionString(String)
        case noOutputFromCommand
        
        public var description: String {
            switch self {
            case .noOutputFromCommand:
                return "No output was returned from command"
            case .unableToFindVersionPattern(let string):
                return "Unable to find version pattern in '\(string)'"
            case .invalidVersionString(let str):
                return "Invalid version string '\(str)'"
            }
        }
    }
    /// Container object for CLI Help Action Handler
    private struct _HelpAction: CLIHelpAction {
        private let handler: CLIHelpActionHandler
        
        public init(_ handler: @escaping CLIHelpActionHandler) {
            self.handler = handler
        }
        
        func execute(parent: CLICommandGroup,
                     argumentStartingAt: Int,
                     arguments: [String],
                     environment: [String: String]?,
                     currentDirectory: URL?,
                     withMessage message: String?,
                     userInfo: [String: Any],
                     stackTrace: CLIStackTrace) throws -> Int32 {
            return try self.handler(parent,
                                    argumentStartingAt,
                                    arguments,
                                    environment,
                                    currentDirectory,
                                    message,
                                    userInfo,
                                    stackTrace)
            
        }
    }
    /// List of parameters used to access help screen
    public static let DefaultHelpArguments: [String] = ["--help", "-help", "-h"]
    
    
    private let swiftVersionRegEx: RegEx = "Swift version ([1-9][0-9]*(\\.[1-9][0-9]*){0,2})"
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftURL: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - helpAction: Handler to handle help parameters
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    public init(swiftURL: URL,
                outputLock: Lockable = NSLock(),
                helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                helpAction: HelpAction = .passthrough,
                outputCapturing: STDOutputCapturing? = nil) {
        
        super.init(outputLock: outputLock,
                   supportPreCommandArguments: true,
                   helpArguments: helpArguments,
                   helpAction: helpAction,
                   outputCapturing: outputCapturing,
                   createCLIProcess: SwiftCLIWrapper.newSwiftProcessMethod(swiftURL: swiftURL))
    }
    
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftURL: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    ///  - helpAction: Handler to handle help parameters
    public convenience init(swiftURL: URL,
                            outputLock: Lockable = NSLock(),
                            helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                            outputCapturing: STDOutputCapturing? = nil,
                            helpActionHandler: @escaping CLIHelpActionHandler) {
        self.init(swiftURL: swiftURL,
                  outputLock: outputLock,
                  helpArguments: helpArguments,
                  helpAction: .custom(_HelpAction(helpActionHandler)),
                  outputCapturing: outputCapturing)
    }
    
    public static func newSwiftProcessMethod(swiftURL: URL) -> (_ arguments: [String],
                                                                _ environment: [String: String]?,
                                                                _ currentDirectory: URL?,
                                                                _ standardInput: Any?,
                                                                _ userInfo: [String: Any],
                                                                _ stackTrace: CLIStackTrace) -> Process {
        
        return {
            (_ arguments: [String],
             _ environment: [String: String]?,
             _ currentDirectory: URL?,
             _ standardInput: Any?,
             _ userInfo: [String: Any],
             _ stackTrace: CLIStackTrace) -> Process in
            
            let rtn = Process()
            rtn.executable = swiftURL
            rtn.arguments = arguments
            
            
            var env = environment ?? ProcessInfo.processInfo.environment
            // Do this because having OS_ACTIVITY_DT_MODE set causes
            // swift to give 'failed to open macho file at'....'
            env["OS_ACTIVITY_DT_MODE"] = nil
            rtn.environment = env
            
            
            if let cd = currentDirectory {
                rtn.currentDirectory = cd
            }
            
            if let sI = standardInput {
                rtn.standardInput = sI
            }
            return rtn
            
        }
    }
    
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftPath: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - helpAction: Handler to handle help parameters
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    public convenience init(swiftPath: String,
                            outputLock: Lockable = NSLock(),
                            helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                            helpAction: HelpAction = .passthrough,
                            outputCapturing: STDOutputCapturing? = nil) {
        self.init(swiftURL: URL(fileURLWithPath: swiftPath),
                  outputLock: outputLock,
                  helpArguments: helpArguments,
                  helpAction: helpAction,
                  outputCapturing: outputCapturing)
    }
    
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftPath: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    ///  - helpAction: Handler to handle help parameters
    public convenience init(swiftPath: String,
                            outputLock: Lockable = NSLock(),
                            helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                            outputCapturing: STDOutputCapturing? = nil,
                            helpActionHandler: @escaping CLIHelpActionHandler) {
        self.init(swiftURL: URL(fileURLWithPath: swiftPath),
                  outputLock: outputLock,
                  helpArguments: helpArguments,
                  helpAction: .custom(_HelpAction(helpActionHandler)),
                  outputCapturing: outputCapturing)
    }
    
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftPath: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - helpAction: Handler to handle help parameters
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    public convenience init(swiftPath: FSPath,
                            outputLock: Lockable = NSLock(),
                            helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                            helpAction: HelpAction = .passthrough,
                            outputCapturing: STDOutputCapturing? = nil) {
        self.init(swiftURL: swiftPath.url,
                  outputLock: outputLock,
                  helpArguments: helpArguments,
                  helpAction: helpAction,
                  outputCapturing: outputCapturing)
    }
    
    /// Create new Swift Wrapper object
    /// - Parameters:
    ///  - swiftPath: The path to the swift executable
    ///  - outputLock: The queue to use to execute output actions in sequential order
    ///  - helpArguments: An array of arguments that can be used to call the help screen
    ///  - outputCapturing: The capturing option to capture data being directed to the output
    ///  - helpAction: Handler to handle help parameters
    public convenience init(swiftPath: FSPath,
                            outputLock: Lockable = NSLock(),
                            helpArguments: [String] = SwiftCLIWrapper.DefaultHelpArguments,
                            outputCapturing: STDOutputCapturing? = nil,
                            helpActionHandler: @escaping CLIHelpActionHandler) {
        self.init(swiftURL: swiftPath.url,
                  outputLock: outputLock,
                  helpArguments: helpArguments,
                  helpAction: .custom(_HelpAction(helpActionHandler)),
                  outputCapturing: outputCapturing)
    }
    
    /// Get the current version of Swift
    public func getVersion() throws -> Version.SingleVersion {
        //print("Running 'swift -version'")
        let swiftVerRet = try self.cli.waitAndCaptureStringResponse(arguments: ["-version"])
        //print("Ran 'swift -version' ")
        
        guard let out = swiftVerRet.out else {
            throw SwiftErrors.noOutputFromCommand
        }
        guard let match = self.swiftVersionRegEx.firstMatch(in: out) else {
            throw SwiftErrors.unableToFindVersionPattern(in: out)
        }
        
        guard let strMatch = match.value(at: 1) else {
            throw SwiftErrors.unableToFindVersionPattern(in: out)
        }
        
        var workingVersionStr = strMatch
        // do a patch for single value version numbers
        if !workingVersionStr.contains(".") {
            workingVersionStr += ".0"
        }
        
        guard let v = Version.SingleVersion(workingVersionStr) else {
            throw SwiftErrors.invalidVersionString(strMatch)
        }
        
        return v
        
    }
    
}
