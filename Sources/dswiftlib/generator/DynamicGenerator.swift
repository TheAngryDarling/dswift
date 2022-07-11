//
//  DynamicGenerator.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2021-12-08.
//

import Foundation
import VersionKit
import XcodeProj
import CLICapture
import PathHelpers

public enum DynamicGeneratorErrors: Error, CustomStringConvertible {
    case noSupportedGenerator(ext: String)
    case mustBeFileURL(URL)
    case compoundError([Error])
    
    public var description: String {
        switch self {
            case .noSupportedGenerator(ext: let ext): return "No supported generator found for extension '\(ext)'"
            case .mustBeFileURL(let url):  return "URL '\(url)' must be a file url"
            case .compoundError(let errors):
                var rtn: String = ""
                for err in errors {
                    if !rtn.isEmpty { rtn += "\n" }
                    rtn += "\(err)"
                }
                return rtn
        }
    }
}

public protocol DynamicGenerator {
    typealias PRINT_SIG = (_ message: String, _ filename: String, _ line: Int, _ funcname: String) -> Void
    
    /// Basic information about the application
    var dswiftInfo: DSwiftInfo { get }
    
    var console: Console { get }
    
    /// The supported extensions for the given generator
    var supportedExtensions: [FSExtension] { get }
    
    /// Initializer for creating a new generator
    init(swiftCLI: CLICapture,
         dswiftInfo: DSwiftInfo,
         console: Console) throws
    
    /// A method to test if the current file can be added to a Xcode Project File
    func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                            inGroup group: XcodeGroup,
                            havingTarget target: XcodeTarget,
                            includeGeneratedFilesInXcodeProject: Bool,
                            using fileManager: FileManager) throws -> Bool
    /// Get the xcode language for the given file
    func languageForXcode(file: XcodeFileSystemURLResource) -> String?
    /// Get the explicit xcode file type for the given file
    func explicitFileTypeForXcode(file: XcodeFileSystemURLResource) -> XcodeFileType?
    
    /// A method to test if the current file can be added to a Xcode Project File
    func canAddToXcodeProject(file: FSPath) -> Bool
    
    
    
    /// Checks to see if there are supported files within the given folder
    func containsSupportedFiles(inFolder folder: FSPath,
                                using fileManager: FileManager) throws -> Bool
    /// Method for cleaning a given folder of any generated source files
    func clean(folder: FSPath,
               using fileManager: FileManager) throws
   
    
    /// Method for generating a source code from the given file
    func generateSource(from source: FSPath,
                        to destination: FSPath,
                        project: SwiftProject,
                        lockGenFiles: Bool,
                        using fileManager: FileManager) throws
    
    /// Returns the generated source file path for the given source
    func generatedFilePath(for source: FSPath,
                           using fileManager: FileManager) throws -> FSPath
    
    /// Check to see if generated source code file exists for the given file
    func generatedFileExists(for source: FSPath,
                             using fileManager: FileManager) throws -> Bool
    /// Checks to see if source code generation is required
    func requiresSourceCodeGeneration(for source: FSPath,
                                      using fileManager: FileManager) throws -> Bool
}
// MARK: - Path function without fileManager parameter
public extension DynamicGenerator {
    /// Checks to see if there are supported files within the given folder
    func containsSupportedFiles(inFolder folder: FSPath) throws -> Bool {
        return try self.containsSupportedFiles(inFolder: folder, using: FileManager.default)
    }
    /// Method for cleaning a given folder of any generated source files
    func clean(folder: FSPath) throws  {
        return try self.clean(folder: folder, using: FileManager.default)
    }
    
    /// Method for generating a source code from the given file
    func generateSource(from source: FSPath,
                        to destination: FSPath,
                        project: SwiftProject,
                        lockGenFiles: Bool) throws {
        try generateSource(from: source,
                           to: destination,
                           project: project,
                           lockGenFiles: lockGenFiles,
                           using: FileManager.default)
    }
    
    /// Returns the generated source file path for the given source
    func generatedFilePath(for source: FSPath) throws -> FSPath {
        return try self.generatedFilePath(for: source,
                                             using: FileManager.default)
    }
    
    /// Returns the generated source file path for the given source
    func generatedFilePath(for source: XcodeFileSystemURLResource,
                           using fileManager: FileManager = .default) throws -> FSPath {
        return try self.generatedFilePath(for: FSPath(source.path),
                                             using: fileManager)
    }
    
    /// Check to see if generated source code file exists for the given file
    func generatedFileExists(for source: FSPath) throws -> Bool {
        return try self.generatedFileExists(for: source,
                                               using: FileManager.default)
    }
    /// Checks to see if source code generation is required
    func requiresSourceCodeGeneration(for source: FSPath) throws -> Bool {
        return try self.requiresSourceCodeGeneration(for: source,
                                                        using: FileManager.default)
    }
}
public extension DynamicGenerator {
    
    
    /// Initializer for creating a new generator
    init(swiftPath: FSPath,
         dswiftInfo: DSwiftInfo,
         console: Console) throws {
        
        if !swiftPath.exists() {
            throw DynamicSourceCodeGenerator.Errors.missingSwift(atPath: swiftPath.string)
        }
        
        let swiftCLI = CLICapture.init(outputLock: Console.sharedOutputLock,
                                       createProcess: SwiftCLIWrapper.newSwiftProcessMethod(swiftURL: swiftPath.url))
        
        try self.init(swiftCLI: swiftCLI,
                      dswiftInfo: dswiftInfo,
                      console: console)
    }
    
    init(dswiftInfo: DSwiftInfo,
         console: Console = .null) throws {
        try self.init(swiftPath: DSwiftSettings.defaultSwiftPath,
                      dswiftInfo: dswiftInfo,
                      console: console)
    }
    
    func generatedFilePath(for source: FSPath,
                           using fileManager: FileManager) throws -> FSPath {
        return source.deletingExtension().appendingExtension("swift")
    }
    
    func generatedFileExists(for source: FSPath,
                             using fileManager: FileManager) throws -> Bool {
        let destinationPath = try generatedFilePath(for: source, using: fileManager)
        return destinationPath.exists()
    }
    /// Check to see if the generated fiel for the source file does not exist or that the destination file is older than the source file
    func checkGeneratedFilesDoesNotExistOrIsOutOfSync(for source: FSPath,
                                                      destination: FSPath,
                                                      using fileManager: FileManager) throws -> Bool {
        guard destination.exists(using: fileManager) else { return true }
        
        self.console.printVerbose("[\(source.lastComponent), \(destination.lastComponent)] Getting file modification dates",
                                  object: self)
        guard let srcMod: Date = source.safely.modificationDate(),
              let desMod: Date = destination.safely.modificationDate() else {
            return true
        }
        // Source is newer than destination, meaning we must rebuild
        self.console.printVerbose("[\(source.lastComponent), \(destination.lastComponent)] Comparing modification dates",
                                  object: self)
        guard srcMod <= desMod else { return true }
        
        return false
        
    }
    /// Check to see if the generated fiel for the source file does not exist or that the destination file is older than the source file
    func checkGeneratedFilesDoesNotExistOrIsOutOfSync(for source: FSPath,
                                                      using fileManager: FileManager) throws -> Bool {
        let dest = try generatedFilePath(for: source, using: fileManager)
        return try checkGeneratedFilesDoesNotExistOrIsOutOfSync(for: source,
                                                                destination: dest,
                                                                using: fileManager)
    }
    func checkForFailedGenerationCommentInDestination(for source: FSPath,
                                                      destination: FSPath,
                                                      using fileManager: FileManager) throws -> Bool {
        self.console.printVerbose("[\(destination.lastComponent)] Checking for failed comment",
                                  object: self)
        self.console.printVerbose("[\(destination.lastComponent)] Loading file",
                                  object: self)
        //self.console.printVerbose("[\(destination.lastComponent)] Reachable: \(try destination.checkResourceIsReachable())", object: self)
        var enc: String.Encoding = .utf8
        let fileContents = try String(contentsOf: destination.url, foundEncoding: &enc)
        self.console.printVerbose("[\(destination.lastComponent)] Looking at file", object: self)
        if fileContents.contains("// Failed to generate source code.") { return true }
        self.console.printVerbose("[\(destination.lastComponent)] Generated source is up-to-date", object: self)
        return false
    }
    
    func requiresSourceCodeGeneration(for source: FSPath,
                                      using fileManager: FileManager) throws -> Bool {
        
        let destination = try generatedFilePath(for: source, using: fileManager)
        
        guard !(try self.checkGeneratedFilesDoesNotExistOrIsOutOfSync(for: source,
                                                                      destination: destination,
                                                                      using: fileManager)) else {
            return true
        }
        
        guard !(try self.checkForFailedGenerationCommentInDestination(for: source,
                                                                      destination: destination,
                                                                      using: fileManager)) else {
            return true
        }
        
        return false
        
    }
    
    func isSupportedFile(_ file: FSPath) -> Bool {
        guard let ext = file.extension else { return false }
        return self.supportedExtensions.contains(ext)
    }
    func isSupportedFile(_ file: XcodeFileSystemURLResource) -> Bool {
        return self.isSupportedFile(FSPath(file.path))
    }
    
    func canAddToXcodeProject(file: FSPath) -> Bool {
        return self.isSupportedFile(file)
    }
    
    func canAddToXcodeProject(file: XcodeFileSystemURLResource) -> Bool {
        return self.canAddToXcodeProject(file: FSPath(file.path))
    }
    
    func containsSupportedFiles(inFolder folder: FSPath,
                                using fileManager: FileManager) throws -> Bool {
        
        let children = try folder.contentsOfDirectory(using: fileManager)
        var folders: [FSPath] = []
        for child in children {
            guard !child.isDirectory(using: fileManager) else {
                folders.append(child)
                continue
            }
            guard child.isFile(using: fileManager) else {
                continue
            }
            
            if self.isSupportedFile(child) {
                return true
            }
        }
        
        for subFolder in folders {
            if (try self.containsSupportedFiles(inFolder: subFolder)) {
                return true
            }
        }
        
        return false
    }
    
    func clean(folder: FSPath,
               using fileManager: FileManager) throws {
        
        let children = try folder.contentsOfDirectory(using: fileManager)
        var folders: [FSPath] = []
        for child in children {
            //if let r = try? child.checkResourceIsReachable(), r {
                guard !child.isDirectory(using: fileManager) else {
                    folders.append(child)
                    continue
                }
                guard child.isFile(using: fileManager) else { continue }
                
                if self.isSupportedFile(child) {
                    let generatedFile = try self.generatedFilePath(for: child)
                    //if let gR = try? generatedFile.checkResourceIsReachable(), gR {
                        
                        do {
                            
                            try generatedFile.remove(using: fileManager)
                            self.console.printVerbose("Removed generated file '\(generatedFile.string)'", object: self)
                            
                        } catch {
                            self.console.printError("Unable to remove generated file '\(generatedFile.string)'", object: self)
                            self.console.printError(error, object: self)
                        }
                    //}
                }
            //}
            
        }
        
        for subFolder in folders {
            try self.clean(folder: subFolder, using: fileManager)
        }
    }
    
}
