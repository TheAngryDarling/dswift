//
//  commandDSwiftBuild.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import PBXProj
import Dispatch

extension Commands {
    
    class OperationStats {
        
        private var _filesCreated: Int = 0
        private var _filesCreatedLock = DispatchQueue(label: "DSwift Build: Files Created Counter Lock")
        public var filesCreated: Int {
            get { return self._filesCreatedLock.sync(execute: { return self._filesCreated }) }
            set { self._filesCreatedLock.sync { self._filesCreated = newValue } }
        }
        
        private var _filesUpdated: Int = 0
        private var _filesUpdatedLock = DispatchQueue(label: "DSwift Build: Files Updated Counter Lock")
        public var filesUpdated: Int {
            get { return self._filesUpdatedLock.sync(execute: { return self._filesUpdated }) }
            set { self._filesUpdatedLock.sync { self._filesUpdated = newValue } }
        }
        
        private var _filesUnchanged: Int = 0
        private var _filesUnchangedLock = DispatchQueue(label: "DSwift Build: Files Unchanged Counter Lock")
        public var filesUnchanged: Int {
            get { return self._filesUnchangedLock.sync(execute: { return self._filesUpdated }) }
            set { self._filesUnchangedLock.sync { self._filesUnchanged = newValue } }
        }
        
        private var _filesFailed: Int = 0
        private var _filesFailedLock = DispatchQueue(label: "DSwift Build: Files Failed Counter Lock")
        public var filesFailed: Int {
            get { return self._filesFailedLock.sync(execute: { return self._filesFailed }) }
            set { self._filesFailedLock.sync { self._filesFailed = newValue } }
        }
        
        private var _filesMissingFromXcode: Int = 0
        // swiftlint:disable:next line_length
        private var _filesMissingFromXcodeLock = DispatchQueue(label: "DSwift Build: Files Missing from Xcode Counter Lock")
        public var filesMissingFromXcode: Int {
            get { return self._filesMissingFromXcodeLock.sync(execute: { return self._filesMissingFromXcode }) }
            set { self._filesMissingFromXcodeLock.sync { self._filesMissingFromXcode = newValue } }
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
    /// DSwift command execution
    static func commandDSwiftBuild(_ args: [String]) throws -> Int32 {
        // Do not do any custom processing if we are just showing the bin path
        guard !args.contains("--show-bin-path") &&
              // Do not do any custom processing if we are just showing the help
              !args.contains("--help") &&
              !args.contains("-h") else {
            return 0
        }
        var returnCode: Int32 = 0
        
        // Check to see if we are building test targets
        let doTestTargets: Bool = (args.firstIndex(of: "--build-tests") != nil || args[0].lowercased() == "test")
        var target: String? = nil // swiftlint:disable:this redundant_optional_initializer
        // Check to see if we are building a specific target
        if let idx = args.firstIndex(of: "--target"), idx < (args.count - 1) {
            target = args[idx + 1]
        }
        
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath, packagePath: currentProjectPath)
        verbosePrint("Package details loaded")
        
        let packageURL: URL = URL(fileURLWithPath: packageDetails.path)
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectURL = packageURL.appendingPathComponent("\(packageDetails.name).xcodeproj", isDirectory: true)
        
        var xcodeProject: XcodeProject? = nil // swiftlint:disable:this redundant_optional_initializer
        if FileManager.default.fileExists(atPath: xCodeProjectURL.path) {
            verbosePrint("Loading xcode project")
            xcodeProject = try XcodeProject(fromURL: xCodeProjectURL)
            verbosePrint("Loaded xcode project")
        }

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
                verbosePrint("Looking at target: \(t.name)")
                let targetPath = URL(fileURLWithPath: t.path, isDirectory: true)
                try processFolder(generator: generator,
                                  inTarget: t.name,
                                  folder: targetPath,
                                  root: packageURL,
                                  rebuild: (args.first?.lowercased() == "rebuild"),
                                  project: xcodeProject,
                                  queue: queue)
            
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        if queue.filesFailed > 0 { returnCode = 1 }
        
        if let p = xcodeProject {
            var anyUpdates: Bool = false
            for xcodeMod in queue.xcodeProjModifications {
                do {
                    let r = try xcodeMod()
                    anyUpdates = anyUpdates || r
                } catch {
                    errPrint("ERROR: Unable to update Xcode Project.\n\(error)")
                    break
                }
            }
            if anyUpdates {
                verbosePrint("Saving Xcode Project")
                try p.save()
                verbosePrint("Xcode Project saved")
            }
        }

        if let tg = target, !hasProcessedTarget {
            printUsage()
            var targetError: String = "\tTarget '\(tg)' not found."
            
            if packageDetails.targets.count > 0 {
                var availableTargets: String = packageDetails.targets.reduce("", { return $0 + ", " + $1.name })
                availableTargets.removeFirst()
                targetError += " Available targets are: \(availableTargets)"
            }
            

            errPrint(targetError)
            returnCode = 1 // Go no further.. We were unable to build target
        }
            
        return returnCode
    }
    
    /// Function called when executed build command
    static func commandXcodeDSwiftBuild(_ args: [String]) throws -> Int32 {
        
        let source = URL(fileURLWithPath: args[1])
        
        do {
            verbosePrint("Loading package details")
           let packageDetails = try PackageDescription(swiftPath: settings.swiftPath, packagePath: currentProjectPath)
           verbosePrint("Package details loaded")
           
           let packageURL: URL = URL(fileURLWithPath: packageDetails.path)
           //let packageName: String = packageURL.lastPathComponent
           
           let xCodeProjectURL = packageURL.appendingPathComponent("\(packageDetails.name).xcodeproj", isDirectory: true)
           var xcodeProject: XcodeProject? = nil
           if FileManager.default.fileExists(atPath: xCodeProjectURL.path) {
               verbosePrint("Loading xcode project")
               xcodeProject = try XcodeProject(fromURL: xCodeProjectURL)
               verbosePrint("Loaded xcode project")
           }
            
            let r = try processFile(generator: generator,
                                    file: source,
                                    root: packageURL,
                                    rebuild: false,
                                    project: xcodeProject)
            
           guard let proj = xcodeProject else {
                errPrint("ERROR: Unable to open Xcode Project '\(xCodeProjectURL.path)'")
                return 1
            }
            guard r.destination.path.hasPrefix(proj.projectFolder.path) else {
                errPrint("ERROR: generated source '\(r.destination.path)' is not within the project")
                return 1
            }
            var localPath = r.destination.path
            localPath.removeFirst(proj.projectFolder.path.count)
            var group: XcodeGroup = proj.resources
            if let idx = localPath.lastIndex(of: "/") { // If we find that the file is in a sub folder we must find the sub group
                let groupPath = String(localPath[..<idx])
                guard let grp = proj.resources.group(atPath: groupPath) else {
                    print("WARNING: Unable to find group '\(groupPath)' to check for file \(localPath.lastPathComponent)")
                    return 0
                }
                group = grp
            }
            guard group.file(atPath: localPath.lastPathComponent) != nil else {
                errPrint("ERROR: File '\(localPath)' is not within the Xcode Project.  Please add it manually and re-build")
                return 0
            }

            return 0
        } catch {
            if error is DynamicSourceCodeGenerator.Errors {
                errPrint("Error: \(error)")
            } else {
                errPrint("Error: Failed to process file '\(args[1])'")
                errPrint(error)
            }
            return 1
        }
        
    }
    
    /// Process a specific supported file
    private static func processFile(generator: DynamicGenerator,
                                    file source: URL,
                                    root: URL,
                                    rebuild: Bool,
                                    project: XcodeProject?) throws -> (destination: URL, updated: Bool, created: Bool) {
        verbosePrint("Looking at file \(source.path)")
        let destination = try generator.generatedFilePath(for: source)
        verbosePrint("Destination: \(destination.path)")
        let destExists = FileManager.default.fileExists(atPath: destination.path)
        verbosePrint("Destination Exists: \(destExists)")
        var doBuild: Bool = !destExists
        if !doBuild { doBuild = try generator.requiresSourceCodeGeneration(for: source) }
         verbosePrint("Requires Building: \(doBuild)")
        
        //doBuild = true
        var updated: Bool = false
        var created: Bool = false
        
        var sourceEncoding: String.Encoding? = nil
        if let p = project {
            let localURL = source.relative(to: root)
            if let r = p.resources.file(atPath: localURL.path) {
                sourceEncoding = r.encoding
            }
        }
        
        
        if doBuild || rebuild {
            do {
                verbosePrint("Processing file \(source.path)")
                try generator.generateSource(from: source, havingEncoding: sourceEncoding, to: destination)
                if destExists { updated = true }
                else { created = true }
            } catch {
                // Removing destination because something failed
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
        
        return (destination: destination, updated: updated, created: created)
    }
    
    /// Look through a specific folder for supported files
    private static func processFolder(generator: DynamicGenerator,
                                      inTarget target: String,
                                      folder: URL,
                                      root: URL,
                                      rebuild: Bool,
                                      project: XcodeProject?,
                                      queue: OperationStats) throws {
        
        verbosePrint("Looking at path: \(folder.path)")
        let children = try FileManager.default.contentsOfDirectory(at: folder,
                                                                   includingPropertiesForKeys: nil)
        var folders: [URL] = []
        for child in children {
            if let r = try? child.checkResourceIsReachable(), r {
                
                guard !child.isPathDirectory else {
                    folders.append(child)
                    continue
                }
                guard child.isPathFile else { continue }
                
                //if dswiftSupportedFileExtensions.contains(child.pathExtension.lowercased()) {
                if generator.isSupportedFile(child) {
                    queue.addOperation {
                        do {
                           
                            let modifications = try processFile(generator: generator,
                                                                file: child,
                                                                root: root,
                                                                rebuild: rebuild,
                                                                project: project)
                            if modifications.created {
                                verbosePrint("Created file '\(modifications.destination.path)'")
                                queue.filesCreated += 1
                            } else if modifications.updated {
                                verbosePrint("Updated file '\(modifications.destination.path)'")
                                queue.filesUpdated += 1
                            } else {
                                verbosePrint("No updates needed for file '\(modifications.destination.path)'")
                                queue.filesUnchanged += 1
                            }
                            
                            if let proj = project {
                                if modifications.destination.path.hasPrefix(proj.projectFolder.path) {

                                    var localPath = modifications.destination.path
                                    localPath.removeFirst(proj.projectFolder.path.count)
                                    var group: XcodeGroup = proj.resources
                                    if let idx = localPath.lastIndex(of: "/") { // If we find that the file is in a sub folder we must find the sub group
                                        let groupPath = String(localPath[..<idx])
                                        
                                        group = try proj.resources.createSubGroup(atPath: groupPath, createFolders: false, savePBXFile: false)
                                    }
                                    
                                    queue.addXcodeModificationOperation {
                                        verbosePrint("Checking for updates to Xcode Project for '\(child.path)'")
                                        let rtn: Bool = try generator.updateXcodeProject(xcodeFile: XcodeFileSystemURLResource(file: child.path),
                                                                                inGroup: group,
                                                                                havingTarget: proj.targets[target]!)
                                        if rtn {
                                            verbosePrint("Updated Xcode Project for '\(child.path)'")
                                        } else {
                                            verbosePrint("No updating Xcode Project needed for '\(child.path)'")
                                        }
                                        return rtn
                                    }

                                }
                            }

                        } catch {
                            if error is DynamicSourceCodeGenerator.Errors {
                                errPrint("Error: \(error)")
                            } else {
                                errPrint("Error: Failed to process file '\(child.path)'\n\(error)")
                            }
                            queue.filesFailed += 1
                        }
                    }

                }
            }
        }
        
        for subFolder in folders {
            try processFolder(generator: generator,
                              inTarget: target,
                              folder: subFolder,
                              root: root,
                              rebuild: rebuild,
                              project: project,
                              queue: queue)
        }
    }
}
