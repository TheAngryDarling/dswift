//
//  commandDSwiftBuild.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import PBXProj

extension Commands {
    
    /// DSwift command execution
    static func commandDSwiftBuild(_ args: [String]) throws -> Int32 {
        guard !args.contains("--show-bin-path") && // Do not do any custom processing if we are just showing the bin path
              !args.contains("--help") && // Do not do any custom processing if we are just showing the help
              !args.contains("-h") else {
            return 0
        }
        var returnCode: Int32 = 0
        //var args = args
        
        // Checkt to see if we're running in verbose mode
        verboseFlag = (args.firstIndex(of: "--verbose") != nil || args.firstIndex(of: "-v") != nil)
        
        // Check to see if we are building test targets
        let doTestTargets: Bool = (args.firstIndex(of: "--build-tests") != nil || args[0].lowercased() == "test")
        var target: String? = nil
        // Check to see if we are building a specific target
        if let idx = args.firstIndex(of: "--target"), idx < (args.count - 1) {
            target = args[idx + 1]
        }
        
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath)
        verbosePrint("Package details loaded")
        
        let packageURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectURL = packageURL.appendingPathComponent("\(packageDetails.name).xcodeproj", isDirectory: true)
        
        var xcodeProject: XcodeProject? = nil
        if FileManager.default.fileExists(atPath: xCodeProjectURL.path) {
            verbosePrint("Loading xcode project")
            xcodeProject = try XcodeProject(fromURL: xCodeProjectURL)
            verbosePrint("Loaded xcode project")
        }
        
        
        
        /*let generator = try DynamicSourceCodeGenerator(swiftPath: settings.swiftPath,
                                                       dSwiftModuleName: dSwiftModuleName,
                                                       dSwiftURL: dSwiftURL,
                                                       print: generatorPrint,
                                                       verbosePrint: generatorVerbosePrint,
                                                       debugPrint: generatorDebugPrint)*/
        
        var hasProcessedTarget: Bool = false
        var projectUpdated: Bool = false
        var dswiftFilesCreated: Int = 0
        var dswiftFilesUpdated: Int = 0
        var dswiftFilesUnchanged: Int = 0
        var dswiftFilesFailed: Int = 0
        var dswiftFilesMissingFromXcode: Int = 0
        for t in packageDetails.targets {
            var canDoTarget: Bool = (t.type != "test" || doTestTargets)
            if let tg = target {
                canDoTarget = (tg.lowercased() == t.name.lowercased())
            }
            
            if (canDoTarget) {
                hasProcessedTarget = true
                verbosePrint("Looking at target: \(t.name)")
                let targetPath = URL(fileURLWithPath: t.path, isDirectory: true)
                let r = try processFolder(generator: generator,
                                          inTarget: t.name,
                                          folder: targetPath,
                                          root: packageURL,
                                          rebuild: (args.first?.lowercased() == "rebuild"),
                                          project: xcodeProject)
                
                dswiftFilesCreated += r.created
                dswiftFilesUpdated += r.updated
                dswiftFilesUnchanged += r.nochange
                dswiftFilesFailed += r.failed
                dswiftFilesMissingFromXcode += r.missingFromXcode
                
                projectUpdated = projectUpdated || r.xcodeProjectUpdated
            }
        }
        if dswiftFilesFailed > 0 { returnCode = 1 }
        
        if let p = xcodeProject, projectUpdated {
            try p.save()
        }
        
        if isRunningFromXcode && !projectUpdated && dswiftFilesMissingFromXcode > 0 {
            errPrint("Error: Files were generated that are not current in the Xcode project.  Please add them or run \(dswiftAppName) package generate-xcodeproj to update the project before re-building")
            returnCode = 1
        }
        /*if projectUpdated && isRunningFromXcode && xcodeProject != nil {
            errPrint("Error: New files were added to the Xcode Project.  A new build is required for Xcode to pickup the new files")
            returnCode = 1
        }*/
        if let tg = target,  !hasProcessedTarget {
            printUsage()
            var targetError: String = "\tTarget '\(tg)' not found."
            
            if packageDetails.targets.count > 0 {
                var availableTargets: String = packageDetails.targets.reduce("", { return $0 + ", " + $1.name })
                availableTargets.removeFirst()
                targetError += " Available targets are: \(availableTargets)"
            }
            
            
            print(targetError)
            returnCode = 1 // Go no further.. We were unable to build target
        }
            
        
        
        return returnCode
    }
    
    /// Function called when executed build command
    static func commandXcodeDSwiftBuild(_ args: [String]) throws -> Int32 {
        /*let generator = try DynamicSourceCodeGenerator(swiftPath: settings.swiftPath,
                                                       dSwiftModuleName: dSwiftModuleName,
                                                       dSwiftURL: dSwiftURL,
                                                       print: generatorPrint,
                                                       verbosePrint: generatorVerbosePrint,
                                                       debugPrint: generatorDebugPrint)*/
        
        let packageURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = URL(fileURLWithPath: args[1])
        
        do {
            _ = try processFile(generator: generator,
                                file: source,
                                root: packageURL,
                                rebuild: false,
                                project: nil)
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
        verbosePrint("Processing file \(source.path)")
        let destination = try generator.generatedFilePath(for: source)
        let destExists = FileManager.default.fileExists(atPath: destination.path)
        var doBuild: Bool = !destExists
        if !doBuild { doBuild = try generator.generateSourceCodeRequired(for: source) }
        
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
                                      project: XcodeProject?) throws -> (updated: Int, created: Int, nochange: Int, failed: Int, missingFromXcode: Int, xcodeProjectUpdated: Bool) {
        
        var updated: Int = 0
        var created: Int = 0
        var nochange: Int = 0
        var failed: Int = 0
        var missingFromXcode: Int = 0
        var xcodeProjectUpdated: Bool = false
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
                    do {
                        let modifications = try processFile(generator: generator,
                                                            file: child,
                                                            root: root,
                                                            rebuild: rebuild,
                                                            project: project)
                        if modifications.created {
                            verbosePrint("Created file '\(modifications.destination.path)'")
                            created += 1
                        } else if modifications.updated {
                            verbosePrint("Updated file '\(modifications.destination.path)'")
                            updated += 1
                        } else {
                            verbosePrint("No updates needed for file '\(modifications.destination.path)'")
                            nochange += 1
                        }
                        
                        
                    } catch {
                        if error is DynamicSourceCodeGenerator.Errors {
                            errPrint("Error: \(error)")
                        } else {
                            errPrint("Error: Failed to process file '\(child.path)'")
                            errPrint(error)
                        }
                        failed += 1
                    }
                }
            }
            
            
            
        }
        
        for subFolder in folders {
            let r = try processFolder(generator: generator,
                                      inTarget: target,
                                      folder: subFolder,
                                      root: root,
                                      rebuild: rebuild,
                                      project: project)
            updated += r.updated
            created += r.created
            nochange += r.nochange
            failed += r.failed
            missingFromXcode += r.missingFromXcode
            xcodeProjectUpdated = xcodeProjectUpdated || r.xcodeProjectUpdated
        }
        
        return (updated: updated, created: created, nochange: nochange, failed: failed, missingFromXcode: missingFromXcode, xcodeProjectUpdated: xcodeProjectUpdated)
    }
}
