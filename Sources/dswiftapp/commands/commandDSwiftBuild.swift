//
//  commandDSwiftBuild.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import dswiftlib
import XcodeProj
import PBXProj
import Dispatch
import CLIWrapper
import CLICapture
import SynchronizeObjects
import PathHelpers

extension Commands {
    
    /// Class containing File Operation Stats
    public class OperationStats {
        
        private let _filesCreated = SyncLockObj<Int>(value: 0)
        
        public var filesCreated: Int {
            get { return  self._filesCreated.value }
            set { self._filesCreated.value = newValue }
        }
        
        private let _filesUpdated = SyncLockObj<Int>(value: 0)
        public var filesUpdated: Int {
            get { return  self._filesUpdated.value }
            set { self._filesUpdated.value = newValue }
        }
        
        private let _filesUnchanged = SyncLockObj<Int>(value: 0)
        public var filesUnchanged: Int {
            get { return  self._filesUnchanged.value }
            set { self._filesUnchanged.value = newValue }
        }
        
        private let _filesFailed = SyncLockObj<Int>(value: 0)
        public var filesFailed: Int {
            get { return  self._filesFailed.value }
            set { self._filesFailed.value = newValue }
        }
        
        private let _filesMissingFromXcode = SyncLockObj<Int>(value: 0)
        public var filesMissingFromXcode: Int {
            get { return  self._filesMissingFromXcode.value }
            set { self._filesMissingFromXcode.value = newValue }
        }
        
        public private(set) var xcodeProjModifications: [() throws -> Bool] = []
        private let _queue: OperationQueue
        public var name: String? {
            get { return self._queue.name }
            set { self._queue.name = newValue  }
        }
        
        public var operationCount: Int { return self._queue.operationCount }
        public var qualityOfService: QualityOfService {
            get { return self._queue.qualityOfService }
            set { self._queue.qualityOfService = newValue }
        }
        
        public var maxConcurrentOperationCount: Int {
            get { return self._queue.maxConcurrentOperationCount }
            set { self._queue.maxConcurrentOperationCount = newValue }
        }
        
        public var isSuspended: Bool { return self._queue.isSuspended }
        
        public init() { self._queue = OperationQueue() }
        
        public func addOperation(_ block: @escaping () -> Void) {
            self._queue.addOperation(block)
        }
        
        public func addXcodeModificationOperation(_ block: @escaping () throws -> Bool) {
            self.xcodeProjModifications.append(block)
        }
        
        public func waitUntilAllOperationsAreFinished() {
            self._queue.waitUntilAllOperationsAreFinished()
        }
        public func cancelAllOperations() {
            self._queue.cancelAllOperations()
        }

    }
    /// Method tries to find/install any missing packages from the providers list
    /// Currently supports providers brew and apt
    /// If settings
    public func tryPreloadingProviderPackages(_ details: PackageDescription) throws {
        #if os(OSX) || os(macOS)
        guard let packages = details.uniqueProviders["brew"] ?? details.uniqueProviders["Brew"] else {
            return
        }
        
        
        // Make sure we actually have packages
        guard packages.count > 0 else { return }
        
        // Check to see if package manager is installed
        guard let commandPath = Commands.which("brew") else {
            self.console.printError("ERROR: Unable to find package manager Homebrew.  Packages \(packages) not verified to be installed", object: self)
            return
        }
        
        let pkgMgrCLI = CLICapture(executable: URL(fileURLWithPath: commandPath))
        
        var hasUpdatedList = false
        
        // Check and install any missing packages
        for package in packages {
            
            if !hasUpdatedList {
                hasUpdatedList = true
                self.console.printVerbose("Updating packages list", object: self)
                
                let updateResponse = try pkgMgrCLI.waitAndCaptureStringResponse(arguments: ["update"],
                                                                              outputOptions: .captureAll)
                
                
                if updateResponse.exitStatusCode != 0 {
                    self.console.printError("WARNING: Update package list failed", object: self)
                    if let errStr = updateResponse.output {
                        //print(errStr)
                        self.console.printError(errStr, object: self)
                    }
                }
            }
            
            // Check to see if already installed
            let infoResponse = try pkgMgrCLI.waitAndCaptureStringResponse(arguments: ["info", package],
                                                                          outputOptions: .captureAll)
            
            
            guard infoResponse.exitStatusCode == 0 else {
                self.console.printError("ERROR: Unable to verify package \(package)", object: self)
                continue
            }
            
            // Convert output to utf8 string
            guard let checkStr = infoResponse.output else {
                self.console.printError("ERROR: Unable to read brew output to verify package \(package)", object: self)
                continue
            }
            
            guard !checkStr.contains("No available formula with the name \"\(package)\"") else {
                self.console.printError("Package \(package) not found.  Try updating Homebrew list", object: self)
                continue
            }
            guard checkStr.contains("Not installed") else {
                continue
            }
            // Install package
            
            guard settings.autoInstallMissingPackages else {
                self.console.printError("WARNING: Missing package \(package).  Please use Homebrew to install", object: self)
                continue
            }
            
            self.console.printVerbose("Installing package \(package)", object: self)
            
            let installResponse = try pkgMgrCLI.waitAndCaptureStringResponse(arguments: ["install", package],
                                                                          outputOptions: .captureAll)
            
            guard installResponse.exitStatusCode == 0 else {
                self.console.printError("ERROR: Unable to install package \(package)", object: self)
                if let installStr = installResponse.output {
                    self.console.printError(installStr, object: self)
                }
                continue
            }
            self.console.printVerbose("Installed package \(package)", object: self)
            
        }
        
        #elseif os(Linux)
        
        guard let packages = details.uniqueProviders["apt"] ?? details.uniqueProviders["Apt"] else {
            return
        }
        
        // Make sure we actually have packages
        guard packages.count > 0 else { return }
        
        // Check to see if package manager is installed
        guard let commandPath = Commands.which("apt-get"),
            let dpkgPath = Commands.which("dpkg") else {
                self.console.printError("ERROR: Unable to find package manager apt-get.  Packages \(packages) not verified to be installed", object: self)
            return
        }
        
        let pkgMgrCLI = CLICapture(executable: URL(fileURLWithPath: commandPath))
        let dpkgMgrCLI = CLICapture(executable: URL(fileURLWithPath: dpkgPath))
        
        var hasUpdatedList = false
        // Check and install any missing packages
        for package in packages {
            
            if !hasUpdatedList {
                hasUpdatedList = true
                self.console.printVerbose("Updating packages list", object: self)
                
                let updateResponse = try pkgMgrCLI.waitAndCaptureStringResponse(arguments: ["update"],
                                                                              outputOptions: .captureAll)
                
                
                if updateResponse.exitStatusCode != 0 {
                    self.console.printError("WARNING: Update package list failed", object: self)
                    if let errStr = updateResponse.output {
                        self.console.printError(errStr, object: self)
                    }
                }
            }
            
            // Check to see if already installed
            let infoResponse = try dpkgMgrCLI.waitAndCaptureStringResponse(arguments: ["-l", package],
                                                                          outputOptions: .captureAll)
            
            guard infoResponse.exitStatusCode == 0 else {
                self.console.printError("ERROR: Unable to verify package \(package)", object: self)
                continue
            }
            
            // Convert output to utf8 string
            guard let checkStr = infoResponse.output else {
                self.console.printError("ERROR: Unable to read apt output to verify package \(package)", object: self)
                continue
            }
            
            guard !checkStr.contains("ii  \(package)") else {
                continue
            }
            
            // Install package
            guard settings.autoInstallMissingPackages else {
                self.console.printError("WARNING: Missing package \(package).  Please use apt-get to install", object: self)
                continue
            }
            
            
            self.console.printVerbose("Installing package \(package)", object: self)
            
            let installResponse = try pkgMgrCLI.waitAndCaptureStringResponse(arguments: ["install", "-y", package],
                                                                          outputOptions: .captureAll)
            
            guard installResponse.exitStatusCode == 0 else {
                self.console.printError("ERROR: Unable to install package \(package)", object: self)
                if let installStr = installResponse.output {
                    self.console.printError(installStr, object: self)
                }
                continue
            }
            self.console.printVerbose("Installed package \(package)", object: self)
        }
        
        #endif
    }
    
    /// DSwift command execution
    public func commandDSwiftBuild(_ parent: CLICommandGroup,
                                   _ argumentStartingAt: Int,
                                   _ arguments: inout [String],
                                   _ environment: [String: String]?,
                                   _ currentDirectory: URL?,
                                   _ userInfo: [String: Any],
                                   _ stackTrace: CLIStackTrace) throws -> Int32 {
        
        let command = arguments[argumentStartingAt-1].lowercased()
        var isRebuild = false
        if command == "rebuild" {
            arguments[argumentStartingAt-1] = "build"
            isRebuild = true
        }
        
        // Do not do any custom processing if we are just showing the bin path
        guard !arguments.contains("--show-bin-path") &&
               // Stop custom processing if we are testing and skipping build process
              !(command == "test" && arguments.contains("--skip-build")) &&
              // Do not do any custom processing if we are just showing the help
              !arguments.contains("--help") &&
              !arguments.contains("-h") else {
            return 0
        }
        
        var returnCode: Int32 = 0
        
        // Check to see if we are building test targets
        let doTestTargets: Bool = (arguments.firstIndex(of: "--build-tests") != nil || command == "test")
        var target: String? = nil // swiftlint:disable:this redundant_optional_initializer
        // Check to see if we are building a specific target
        if let idx = arguments.firstIndex(of: "--target"), idx < (arguments.count - 1) {
            target = arguments[idx + 1]
        }
        
        self.console.printVerbose("Loading package details", object: self)
        var pkgDetails: PackageDescription? = nil
        var pkgDetailsTryCount = 0
        var missingPackageName: String? = nil
        var missingPackageURL: String? = nil
        var missingPackageVersion: String? = nil
        
        repeat {
            do {
                pkgDetails = try PackageDescription(swiftPath: settings.swiftPath,
                                                    packagePath: self.currentProjectPath,
                                                    loadDependencies: true,
                                                    console: console)
            } catch PackageDescription.Error.dependencyMissingLocalPath(name: let name, url: let url, let version) {
                self.console.printVerbose("WARING: Missing dependency locally.  Trying package update to resolve all missing dependencies.", object: self)
                pkgDetailsTryCount += 1
                missingPackageName = name
                missingPackageURL = url
                missingPackageVersion = version
                
                // try updating the package to resolve missing dependencies
                _ = try parent.execute(["package", "update"])
                //_ = self.commandSwift(["package", "update"])
            } catch PackageDescription.Error.unsupportedPackageSchemaVersion(schemaPath: let path,
                                                                             version: let ver) {
                self.console.printVerbose("Unsupported Package Schema version \(ver)")
                try? FileManager.default.removeItem(atPath: path)
                pkgDetailsTryCount += 1
                _ = try parent.execute(["package", "update"])
            }
        } while (pkgDetails == nil && pkgDetailsTryCount < 2)
        
        guard let packageDetails = pkgDetails else {
            throw PackageDescription.Error.dependencyMissingLocalPath(name: missingPackageName!,
                                                                      url: missingPackageURL!,
                                                                      version: missingPackageVersion!)
        }
        self.console.printVerbose("Package details loaded", object: self)
        
        let packagePath: FSPath = packageDetails.path
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectPath = packagePath.resolvingSymlinks.appendingComponent("\(packageDetails.name).xcodeproj")
        
        let xcodeProject: XcodeProject? = try {
            guard xCodeProjectPath.exists() else {
                return nil
            }
            self.console.printVerbose("Loading Xcode project", object: self)
            let rtn = try XcodeProject(fromURL: xCodeProjectPath.url)
            self.console.printVerbose("Loaded Xcode project", object: self)
            return rtn
        }()
        
        let swiftProject: SwiftProject = SwiftProject(rootPath: packagePath,
                                                      xcodeProject: xcodeProject) // swiftlint:disable:this redundant_optional_initializer

        let queue = OperationStats()
        
        queue.name = "DSwift Build Queue"
        var hasProcessedTarget: Bool = false
        
        for t in packageDetails.targets {
            var canDoTarget: Bool = (t.type != "test" || doTestTargets)
            if let tg = target {
                canDoTarget = (tg.lowercased() == t.name.lowercased())
            }
            
            if canDoTarget {
                hasProcessedTarget = true
                self.console.printVerbose("Looking at target: \(t.name)", object: self)
                let targetPath = t.path.resolvingSymlinks
                try processFolder(generator: generator,
                                  inTarget: t.name,
                                  folder: targetPath,
                                  rebuild: isRebuild,
                                  project: swiftProject,
                                  queue: queue,
                                  using: .default)
            
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        if queue.filesFailed > 0 { returnCode = 1 }
        
        if swiftProject.hasXcodeProject {
            var anyUpdates: Bool = false
            for xcodeMod in queue.xcodeProjModifications {
                do {
                    let r = try xcodeMod()
                    anyUpdates = anyUpdates || r
                } catch {
                    self.console.printError("ERROR: Unable to update Xcode Project.\n\(error)",
                                        object: self)
                    break
                }
            }
            if anyUpdates {
                self.console.printVerbose("Saving Xcode Project", object: self)
                try swiftProject.saveXcodeProject()
                self.console.printVerbose("Xcode Project saved", object: self)
            }
        }

        if let tg = target, !hasProcessedTarget {
            var targetError: String = "\tTarget '\(tg)' not found."
            
            if packageDetails.targets.count > 0 {
                var availableTargets: String = packageDetails.targets.reduce("", { return $0 + ", " + $1.name })
                availableTargets.removeFirst()
                targetError += " Available targets are: \(availableTargets)"
            }
            
            try parent.executeHelp(argumentStartingAt: argumentStartingAt,
                                   arguments: arguments,
                                   environment: environment,
                                   currentDirectory: currentDirectory,
                                   withMessage: targetError)
            returnCode = 1 // Go no further.. We were unable to build target
        }
           
        if returnCode == 0 {
            // Try installing any required missing system packages
            try tryPreloadingProviderPackages(packageDetails)
        }
        
        return returnCode
    }
    
    /// Function called when executed build command
    public func commandXcodeDSwiftBuild(_ parent: CLICommandGroup,
                                        _ argumentStartingAt: Int,
                                        _ arguments: [String],
                                        _ environment: [String: String]?,
                                        _ currentDirectory: URL?,
                                        _ standardInput: Any?,
                                        _ userInfo: [String: Any],
                                        _ stackTrace: CLIStackTrace) throws -> Int32 {
        
        var currentDir = FSPath((currentDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).path)
        
        if let path = ( ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? ProcessInfo.processInfo.environment["SRCROOT"] ?? ProcessInfo.processInfo.environment["SOURCE_ROOT"]) {
            currentDir = FSPath(path)
        }
        
        
        let source = FSPath(arguments[1])
        
        do {
           self.console.printVerbose("Loading package details", object: self)
           let packageDetails = try PackageDescription(swiftPath: settings.swiftPath,
                                                       packagePath: currentDir,
                                                       loadDependencies: false,
                                                       console: self.console)
           self.console.printVerbose("Package details loaded", object: self)
           
           let packagePath = packageDetails.path
           //let packageName: String = packageURL.lastPathComponent
           
           let xCodeProjectPath = packagePath.resolvingSymlinks.appendingComponent("\(packageDetails.name).xcodeproj")
            
            let xcodeProject: XcodeProject? = try {
                guard xCodeProjectPath.exists() else {
                    return nil
                }
                self.console.printVerbose("Loading Xcode project", object: self)
                let rtn = try XcodeProject(fromURL: xCodeProjectPath.url)
                self.console.printVerbose("Loaded Xcode project", object: self)
                return rtn
            }()
            
            let swiftProject: SwiftProject = SwiftProject(rootPath: packagePath,
                                                          xcodeProject: xcodeProject) // swiftlint:disable:this redundant_optional_initializer
            
            let r = try processFile(generator: generator,
                                    file: source,
                                    rebuild: false,
                                    project: swiftProject,
                                    using: .default)
            
           guard let proj = xcodeProject else {
               self.console.printError("ERROR: Unable to open Xcode Project '\(xCodeProjectPath)'",
                                   object: self)
                return 1
            }
            guard r.destination.string.hasPrefix(proj.projectFolder.path) else {
                self.console.printError("ERROR: generated source '\(r.destination)' is not within the project",
                                    object: self)
                return 1
            }

            return 0
        } catch {
            if error is DynamicSourceCodeGenerator.Errors {
                self.console.printError("Error: \(error)", object: self)
            } else {
                self.console.printError("Error: Failed to process file '\(source)'",
                                        object: self)
                self.console.printError(error, object: self)
            }
            return 1
        }
        
    }
    
    /// Process a specific supported file
    private func processFile(generator: DynamicGenerator,
                             file source: FSPath,
                             rebuild: Bool,
                             project: SwiftProject,
                             using fileManager: FileManager) throws -> (destination: FSPath, updated: Bool, created: Bool) {
        self.console.printVerbose("Looking at file \(source)", object: self)
        let destination = try generator.generatedFilePath(for: source, using: fileManager)
        self.console.printVerbose("Destination: \(destination)", object: self)
        let destExists = destination.exists(using: fileManager)
        self.console.printVerbose("Destination Exists: \(destExists)", object: self)
        var doBuild: Bool = !destExists
        if !doBuild {
            doBuild = try generator.requiresSourceCodeGeneration(for: source,
                                                                    using: fileManager)
        }
        
        self.console.printVerbose("Requires Building: \(doBuild)", object: self)
        
        //doBuild = true
        var updated: Bool = false
        var created: Bool = false
        
        //let sourceEncoding: String.Encoding? = project.file(at: source)?.encoding
        
        
        if doBuild || rebuild {
            do {
                self.console.printVerbose("Processing file \(source)", object: self)
                try generator.generateSource(from: source,
                                             //havingEncoding: sourceEncoding,
                                             to: destination,
                                             project: project,
                                             lockGenFiles: settings.lockGenFiles,
                                             using: fileManager)
                if destExists { updated = true }
                else { created = true }
            } catch {
                // Removing destination because something failed
                try? destination.remove(using: fileManager)
                throw error
            }
        }
        
        return (destination: destination, updated: updated, created: created)
    }
    
    /// Look through a specific folder for supported files
    private func processFolder(generator: DynamicGenerator,
                               inTarget target: String,
                               folder: FSPath,
                               rebuild: Bool,
                               project: SwiftProject,
                               queue: OperationStats,
                               using fileManager: FileManager) throws {
        
        self.console.printVerbose("Looking at path: \(folder)", object: self)
        let children = try folder.contentsOfDirectory(using: fileManager)
        var folders: [FSPath] = []
        for child in children {
            //if let r = try? child.checkResourceIsReachable(), r {
                guard !child.isDirectory(using: fileManager) else {
                    folders.append(child)
                    continue
                }
                guard child.isFile(using: fileManager) &&
                      generator.isSupportedFile(child) else {
                    continue
                }
                
                
                queue.addOperation {
                    do {
                       
                        let modifications = try self.processFile(generator: generator,
                                                                 file: child,
                                                                 rebuild: rebuild,
                                                                 project: project,
                                                                 using: fileManager)
                        if modifications.created {
                            self.console.printVerbose("Created file '\(modifications.destination)'",
                                                      object: self)
                            queue.filesCreated += 1
                        } else if modifications.updated {
                            self.console.printVerbose("Updated file '\(modifications.destination)'",
                                                      object: self)
                            queue.filesUpdated += 1
                        } else {
                            self.console.printVerbose("No updates needed for file '\(modifications.destination)'",
                                                      object: self)
                            queue.filesUnchanged += 1
                        }
                        
                        if project.hasXcodeProject {
                            
                            
                            if let relPath = modifications.destination.relative(to: FSPath(project.xcodeProjectFolder!.path)) {

                                var group: XcodeGroup = project.xcodeResources
        
                                // If we find that the file is in a sub folder we must find the sub group
                                if relPath.hasSubDirectories {
                                    
                                    group = try project.xcodeResources.createSubGroup(atPath: "/" + relPath.deletingLastComponent().string,
                                                                                      createFolders: false,
                                                                                      savePBXFile: false)
                                    
                                }
                                
                                queue.addXcodeModificationOperation {
                                    self.console.printVerbose("Checking for updates to Xcode Project for '\(child)'",
                                                              object: self)
                                    let rtn: Bool = try generator.updateXcodeProject(xcodeFile: XcodeFileSystemURLResource(file: child.string),
                                                                            inGroup: group,
                                                                            havingTarget: project.xcodeTargets[target]!,
                                                                                     includeGeneratedFilesInXcodeProject: self.settings.includeGeneratedFilesInXcodeProject,
                                                                                     using: fileManager)
                                    if rtn {
                                        self.console.printVerbose("Updated Xcode Project for '\(child)'", object: self)
                                    } else {
                                        self.console.printVerbose("No updating Xcode Project needed for '\(child)'", object: self)
                                    }
                                    return rtn
                                }

                            }
                        }

                    } catch {
                        if error is DynamicSourceCodeGenerator.Errors {
                            self.console.printError("Error: \(error)", object: self)
                        } else {
                            self.console.printError("Error: Failed to process file '\(child)'\n\(error)", object: self)
                        }
                        queue.filesFailed += 1
                    }
                }

            //}
        }
        let excludedRootChildFolders: [String] = ["build",
                                                  ".build",
                                                  ".swiftpm",
                                                  ".git",
                                                  "DerivedData"]
        for subFolder in folders {
            // If we are in the root folder, make sure we are not a special folder that we know is not part of the sources
            guard ((folder != project.rootPath) || (!excludedRootChildFolders.contains(subFolder.lastComponent))) else {
                continue
            }
            try self.processFolder(generator: generator,
                                  inTarget: target,
                                  folder: subFolder,
                                  rebuild: rebuild,
                                  project: project,
                                  queue: queue,
                                   using: fileManager)
        }
    }
}
