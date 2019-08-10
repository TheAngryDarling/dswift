//
//  commandPackage.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import PBXProj


fileprivate struct SHConfigFile {
    private let path: String
    private var content: String = ""
    private var encoding: String.Encoding = .utf8
    
    public init(_ path: String) throws {
        let pth = NSString(string: path).expandingTildeInPath
        self.path = pth
        if FileManager.default.fileExists(atPath: pth) {
            self.content = try String(contentsOfFile: pth, usedEncoding: &self.encoding)
        }
    }
    
    public func save() throws {
        try self.content.write(toFile: self.path, atomically: true, encoding: self.encoding)
    }
    
    public func contains(_ element: String) -> Bool {
        return self.content.contains(element)
    }
    
    public static func +=(lhs: inout SHConfigFile, rhs: String) {
        lhs.content += rhs
    }
}



extension Commands {
    /// Post execution method for swift package
    static func commandPackage(_ args: [String]) throws -> Int32 {
        
        var arguments = args
        //arguments.removeFirst() //First parameter is the package param
        //guard let cmd = arguments.last?.lowercased() else { return 0 }
        
        if arguments.contains("--help") {
            return try commandPackageHelp(args)
        } else if arguments.contains("clean") {
            return try commandPackageClean(arguments, Commands.commandSwift(args))
        } else if arguments.contains("reset") {
            return try commandPackageReset(arguments, Commands.commandSwift(args))
        } else if arguments.contains("update") {
            return try commandPackageUpdate(arguments, Commands.commandSwift(args))
        } else if arguments.contains("generate-xcodeproj") {
            return try commandPackageGenXcodeProj(arguments, Commands.commandSwift(args))
        } else if arguments.contains("generate-completion-script") {
            return try commandPackageGenAutoScript(arguments)
        } else if arguments.contains("install-completion-script") {
            return try commandPackageInstallAutoScript(arguments)
        } else if arguments.count > 2 && arguments[arguments.count - 3].lowercased() == "init" {
            return try commandPackageInit(arguments, Commands.commandSwift(args))
        } else {
            return Commands.commandSwift(args)
        }
    }
    
    /// Clean any swift files build from dswift
    private static func cleanDSwiftBuilds() throws {
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath)
        verbosePrint("Package details loaded")
        
        for t in packageDetails.targets {
            
            verbosePrint("Looking at target: \(t.name)")
            let targetPath = URL(fileURLWithPath: t.path, isDirectory: true)
            try cleanFolder(fileExtension: dswiftFileExtension, folder: targetPath)
            
        }
    }
    
    
    /// Clean a folder of any swift files build from dswift
    static func cleanFolder(fileExtension: String, folder: URL) throws {
        //verbosePrint("Looking at path: \(folder.path)")
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
                
                if child.pathExtension.lowercased() == fileExtension.lowercased() {
                    let generatedFile = child.deletingPathExtension().appendingPathExtension("swift")
                    if let gR = try? generatedFile.checkResourceIsReachable(), gR {
                        
                        do {
                            
                            try FileManager.default.removeItem(at: generatedFile)
                            verbosePrint("Removed generated file '\(generatedFile.path)'")
                            
                        } catch {
                            print("Unable to remove generated file '\(generatedFile.path)'")
                            print(error)
                        }
                    }
                }
            }
            
            
            
        }
        
        for subFolder in folders {
            try cleanFolder(fileExtension: fileExtension, folder: subFolder)
        }
    }
    
    /// swift package clean catcher
    private static func commandPackageClean(_ args: [String], _ retCode: Int32) throws -> Int32 {
        try cleanDSwiftBuilds()
        return retCode
    }
    
    /// swift package update catcher
    private static func commandPackageUpdate(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 && settings.regenerateXcodeProject else { return retCode }
        
        return try processCommand(["package", "generate-xcodeproj"])
    }
    
    /// swift package reset catcher
    private static func commandPackageReset(_ args: [String], _ retCode: Int32) throws -> Int32 {
        try cleanDSwiftBuilds()
        return retCode
    }
    
    /// swift package generate-xcodeproj catcher
    private static func _commandPackageGenAutoScript(_ args: [String]) throws -> (String, Int32) {
        let task = Process()
        
        task.executable = URL(fileURLWithPath: settings.swiftPath)
        task.arguments = args
        
        let pipe = Pipe()
        defer {
            pipe.fileHandleForReading.closeFile()
            pipe.fileHandleForWriting.closeFile()
        }
        //#if os(macOS)
        //task.standardInput = FileHandle.nullDevice
        //#endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        try! task.execute()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var str = String(data: data, encoding: .utf8)!
        
        guard task.terminationStatus == 0 else {
            return (str, task.terminationStatus)
        }
        
        if args.last == "bash" {
            str = str.replacingOccurrences(of: "build run package test", with: "build rebuild run package test")
            str = str.replacingOccurrences(of: "clean generate-completion-script", with: "clean generate-completion-script install-completion-script")
            
            let checkBuildBlock: String = "(build)"
            let replaceBuildBlock: String = """
            (build)
                        _swift_build 2
                        ;;
                    (rebuild)
            """
             str = str.replacingOccurrences(of: checkBuildBlock, with: replaceBuildBlock)
            
            let checkCompletionBlock: String = "(generate-completion-script)"
            let replaceCompletiondBlock: String = """
            (generate-completion-script)
                        _swift_package_generate-completion-script $(($1+1))
                        return
                        ;;
                    (install-completion-script)
            """
            str = str.replacingOccurrences(of: checkCompletionBlock, with: replaceCompletiondBlock)
            
            
            str = str.replacingOccurrences(of: "complete -F _swift swift", with: "complete -F _swift \(dswiftAppName)")
            
            str = str.replacingOccurrences(of: "_swift", with: "_\(dswiftAppName)")
            
        } else if args.last == "zsh" {
            str = str.replacingOccurrences(of: "#compdef swift", with: "#compdef \(dswiftAppName)")
            str = str.replacingOccurrences(of: "                'build:build sources into binary products'",
                                           with: "                'build:build sources into binary products'\n                'rebuild:rebuild \(dswiftAppName) files then build sources into binary products'")
            
            str = str.replacingOccurrences(of: "                'generate-completion-script:Generate completion script (Bash or ZSH)'",
                                           with: "                'generate-completion-script:Generate completion script (Bash or ZSH)'\n                'install-completion-script:Install completion script (Bash or ZSH)'")
            
            let checkBuildBlock: String = "(build)"
            let replaceBuildBlock: String = """
            (build)
                                _swift_build
                                ;;
                            (rebuild)
            """
            
            str = str.replacingOccurrences(of: checkBuildBlock, with: replaceBuildBlock)
            
            let checkCompletionBlock: String = "(generate-completion-script)"
            let replaceCompletionBlock: String = """
            (generate-completion-script)
                                _swift_package_generate-completion-script
                                ;;
                            (install-completion-script)
            """
            
            str = str.replacingOccurrences(of: checkCompletionBlock, with: replaceCompletionBlock)
            
            str = str.replacingOccurrences(of: "_swift", with: "_\(dswiftAppName)")
            
        }
        
        return (str, task.terminationStatus)
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageGenAutoScript(_ args: [String]) throws -> Int32 {
        let r = try _commandPackageGenAutoScript(args)
        print(r.0)
        return r.1
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageInstallAutoScript(_ args: [String]) throws -> Int32 {
        
        if args.last == "bash" {
            var bashProfile: SHConfigFile
            do { bashProfile = try SHConfigFile("~/.bash_profile") }
            catch {
                errPrint("Unable to load ~/.bash_profile")
                return 1
            }
            guard !bashProfile.contains("which \(dswiftAppName)") else {
                print("Autocomplete script was previously installed")
                return 0
            }
            
            bashProfile += """
            
            # Source Dynamic Swift completion
            if [ -n "`which \(dswiftAppName)`" ]; then
            eval "`\(dswiftAppName) package generate-completion-script bash`"
            fi
            """
            
            do { try bashProfile.save() }
            catch {
                errPrint("Unable to save ~/.bash_profile")
                return 1
            }
            
            print("Autocomplete script installed.  Please run source ~/.bash_profile")
            
            return 0
        } else if args.last == "zsh" {
            
            
            let zshFolderPath: String = NSString(string: "~/.zsh").expandingTildeInPath
            let zshProfilePath: String = NSString(string: "~/.zsh/_\(dswiftAppName)").expandingTildeInPath
            guard !FileManager.default.fileExists(atPath: zshProfilePath) else {
                print("Autocomplete script was previously installed")
                return 0
            }
            if !FileManager.default.fileExists(atPath: zshFolderPath) {
                do {
                    try FileManager.default.createDirectory(atPath: zshFolderPath, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    errPrint("Unable to create ~/.zsh folder")
                    return 1
                }
            }
            
            let zshScript = try _commandPackageGenAutoScript(["package", "generate-completion-script", "zsh"])
            guard zshScript.1 == 0 else {
                errPrint("An error occured while trying to generate script")
                errPrint(zshScript.0)
                return zshScript.1
            }
            
            do { try zshScript.0.write(toFile: zshProfilePath, atomically: true, encoding: .utf8) }
            catch {
                errPrint("Unable to save ~/.zsh/_\(dswiftAppName)")
                return 1
            }
            
            
            var zshProfile: SHConfigFile
            do { zshProfile = try SHConfigFile("~/.zshrc") }
            catch {
                errPrint("Unable to load ~/.zshrc")
                return 1
            }
            
            guard !zshProfile.contains("fpath=(~/.zsh $fpath)") else {
                return 0
            }
            
            zshProfile += "fpath=(~/.zsh $fpath)\n"
            
            do { try zshProfile.save() }
            catch {
                errPrint("Unable to save ~/.zshrc")
                return 1
            }
            
           print("Autocomplete script installed.  Please run compinit")
            
            return 0
         } else if args.last == "--help" {
            let msg: String = """
            OVERVIEW: Install completion script (Bash or ZSH)

            COMMANDS:
              flavor   Shell flavor (bash or zsh)
            """
            print(msg)
            return 0
        } else {
            errPrint("error: unknown value '\(args.last!)' for argument flavor; use --help to print usage")
            return 1
        }
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageHelp(_ args: [String]) throws -> Int32 {
        
        let task = Process()
        
        task.executable = URL(fileURLWithPath: settings.swiftPath)
        task.arguments = args
        
        let pipe = Pipe()
        defer {
            pipe.fileHandleForReading.closeFile()
            pipe.fileHandleForWriting.closeFile()
        }
        //#if os(macOS)
        //task.standardInput = FileHandle.nullDevice
        //#endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        try! task.execute()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var str = String(data: data, encoding: .utf8)!
        
        str = str.replacingOccurrences(of: "USAGE: swift", with: "USAGE: \(dswiftAppName)")
        guard task.terminationStatus == 0 else {
            errPrint(str)
            return task.terminationStatus
        }
        
        str = str.replacingOccurrences(of: "  generate-completion-script\n                          Generate completion script (Bash or ZSH)",
                                       with: "  generate-completion-script\n                          Generate completion script (Bash or ZSH)\n  install-completion-script\n                          Install completion script (Bash or ZSH)")
        
        print(str)
        
        return task.terminationStatus
    }
    
    /// swift package init catcher
    private static func commandPackageInit(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 else { return retCode }
        guard (args.firstIndex(of: "--help") == nil) else { return retCode }
        
        try settings.readme.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("README.md"),
                                  for: args.last!.lowercased(),
                                  withName: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent)
        
        /// Setup license file
        try settings.license.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("LICENSE.md"))
        
        return retCode
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageGenXcodeProj(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 else { return retCode }
        guard (args.firstIndex(of: "--help") == nil) else { return retCode }
        
        var returnCode: Int32 = 0
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath)
        verbosePrint("Package details loaded")
        
        let packageURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectURL = packageURL.appendingPathComponent("\(packageDetails.name).xcodeproj", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: xCodeProjectURL.path) else {
            errPrint("Project not found. \(xCodeProjectURL.path)")
            return 1
        }
        verbosePrint("Loading xcode project")
        let xcodeProject = try XcodeProject(fromURL: xCodeProjectURL)
        verbosePrint("Loaded xcode project")
        
        
        
        for tD in packageDetails.targets {
            //guard tD.type.lowercased() != "test" else { continue }
            let relativePath = tD.path.replacingOccurrences(of: FileManager.default.currentDirectoryPath, with: "")
            if let t = xcodeProject.targets.first(where: { $0.name == tD.name}),
                let nT = t as? XcodeNativeTarget,
                let targetGroup = xcodeProject.resources.group(atPath: relativePath)  {
                //let targetGroup = xcodeProject.resources.group(atPath: "Sources/\(tD.name)")!
                let rCode = try addDSwiftFilesToTarget(in: XcodeFileSystemURLResource(directory: tD.path),
                                           inGroup: targetGroup,
                                           havingTarget: nT,
                                           usingProvider: xcodeProject.fsProvider)
                if rCode != 0 {
                    returnCode = rCode
                }
                
                let rule = try nT.createBuildRule(name: "Dynamic Swift",
                                                   compilerSpec: "com.apple.compilers.proxy.script",
                                                   fileType: XcodeFileType.Pattern.proxy,
                                                   editable: true,
                                                   filePatterns: "*.dswift",
                                                   outputFiles: ["$(INPUT_FILE_DIR)/$(INPUT_FILE_BASE).swift"],
                                                   outputFilesCompilerFlags: nil,
                                                   script: "",
                                                   atLocation: .end)
                rule.script = """
                if ! [ -x "$(command -v \(dswiftAppName))" ]; then
                    echo "Error: \(dswiftAppName) is not installed.  Please visit \(dSwiftURL) to download and install." >&2
                    exit 1
                fi
                \(dswiftAppName) xcodebuild ${INPUT_FILE_PATH}
                """
            }
        }
 
 
        if settings.xcodeResourceSorting == .sorted {
            xcodeProject.resources.sort()
        }
        
        var indexAfterLastPackagFile: Int = 1
        
        
        let children = try xcodeProject.fsProvider.contentsOfDirectory(at: xcodeProject.projectFolder)
        for child in children {
            if child.lastPathComponent.compare("^Package\\@swift-.*\\.swift$", options: .regularExpression) == .orderedSame {
                try xcodeProject.resources.addExisting(child,
                                                       atLocation: .index(indexAfterLastPackagFile),
                                                       savePBXFile: false)
                indexAfterLastPackagFile += 1
            }
        }
        
        let additionalFiles: [String] = ["LICENSE.md", "README.md"]
        
        for file in additionalFiles {
            if let xcodeFile = children.first(where: { $0.lastPathComponent == file }) {
                try xcodeProject.resources.addExisting(xcodeFile,
                                                       atLocation: .index(indexAfterLastPackagFile),
                                                       savePBXFile: false)
                indexAfterLastPackagFile += 1
            }
        }
        
        //debugPrint(xcodeProject)
        try xcodeProject.save()
    
        return returnCode
    }
    
    /// Adds dswift files to Xcode Project
    internal static func addDSwiftFilesToTarget(in url: XcodeFileSystemURLResource,
                                                inGroup group: XcodeGroup,
                                                havingTarget target: XcodeTarget,
                                                usingProvider provider: XcodeFileSystemProvider) throws -> Int32 {
        func hasDSwiftSubFiles(in url: XcodeFileSystemURLResource, usingProvider provider: XcodeFileSystemProvider) throws -> Bool {
            let children = try provider.contentsOfDirectory(at: url)
            /*let children = try FileManager.default.contentsOfDirectory(atPath: url.path).map {
                return url.appendingPathComponent($0)
            }*/
            for child in children {
                // Check current dir for files
                if child.pathExtension.lowercased() == dswiftFileExtension, child.isFile /*child.isPathFile*/ {
                    return true
                }
            }
            for child in children {
                // Check sub dir for files
                //if child.isPathDirectory {
                if child.isDirectory {
                    if (try hasDSwiftSubFiles(in: child, usingProvider: provider)) { return true }
                }
            }
            return false
        }
        
        var rtn: Int32 = 0
        
        let children = try provider.contentsOfDirectory(at: url)
        /*let children = try FileManager.default.contentsOfDirectory(atPath: url.path).map {
            return url.appendingPathComponent($0)
        }*/
        
        for child in children {
            if child.pathExtension.lowercased() == dswiftFileExtension, child.isFile /*child.isPathFile*/ {
                if group.file(atPath: child.lastPathComponent) == nil {
                    // Only add the dswift file to the project if its not already there
                    let f = try group.addExisting(child,
                                                  copyLocally: true,
                                                  savePBXFile: false) as! XcodeFile
                    f.languageSpecificationIdentifier = "xcode.lang.swift"
                    target.sourcesBuildPhase().createBuildFile(for: f)
                    //print("Adding dswift file '\(child.path)'")
                }
                let swiftName = NSString(string: child.lastPathComponent).deletingPathExtension + ".swift"
                if let f = group.file(atPath: swiftName) {
                    var canRemoveSource: Bool = true
                    do {
                        let source = try String(contentsOf: URL(fileURLWithPath: f.fullPath))
                        if !source.hasPrefix("//  This file was dynamically generated from") {
                            rtn = 1
                            errPrint("Error: Source file '\(f.fullPath)' matches build file name for '\(child.path)' and is NOT a generated file")
                            canRemoveSource = false
                        }
                        
                    } catch { }
                    if canRemoveSource {
                        // Remove the generated swift file if its there
                        try f.remove(deletingFiles: false, savePBXFile: false)
                    }
                }
                //target.sourcesBuildPhase().createBuildFile(for: file)
            }
        }
        
        
        for child in children {
            if child.isDirectory, (try hasDSwiftSubFiles(in: child, usingProvider: provider)) {
                var childGroup = group.group(atPath: child.pathComponents.last!)
                if  childGroup == nil {
                    childGroup = try group.createGroup(withName: child.pathComponents.last!)
                }
                
                let rCode = try addDSwiftFilesToTarget(in: child,
                                                       inGroup: childGroup!,
                                                       havingTarget: target,
                                                       usingProvider: provider)
                
                if rtn == 0 && rCode > 0 { rtn = rCode }
            }
        }
        
        return rtn
        
    }
    
    
    
}
