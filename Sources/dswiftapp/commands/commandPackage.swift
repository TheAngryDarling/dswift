//
//  commandPackage.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import PBXProj
import VersionKit
import dswiftlib
import CLICapture
import CLIWrapper
import PathHelpers

extension Commands {
    
    /// Clean any swift files build from dswift
    public func cleanResetDSwiftBuilds(_ parent: CLICommandGroup,
                                       _ argumentStartingAt: Int,
                                       _ arguments: inout [String],
                                       _ environment: [String: String]?,
                                       _ currentDirectory: URL?,
                                       _ userInfo: [String: Any],
                                       _ stackTrace: CLIStackTrace) throws -> Int32 {
        self.console.printVerbose("Loading package details", object: self)
        let packageDetails = try PackageDescription(swiftCommand: settings.swiftCommand,
                                                    packagePath: self.currentProjectPath,
                                                    loadDependencies: false,
                                                    console: self.console)
        self.console.printVerbose("Package details loaded", object: self)
        
        for t in packageDetails.targets {
            
            self.console.printVerbose("Looking at target: \(t.name)", object: self)
            let targetPath = t.path.resolvingSymlinks
            
            try generator.clean(folder: targetPath)
            
        }
        
        return 0
    }
    
    public func commandPackageUpdate(_ parent: CLICommandGroup,
                                     _ argumentStartingAt: Int,
                                     _ arguments: [String],
                                     _ environment: [String: String]?,
                                     _ currentDirectory: URL?,
                                     _ response: CLICapturedStringResponse,
                                     _ userInfo: [String: Any],
                                     _ stackTrace: CodeStackTrace) throws -> Int32 {
        let retCode = response.exitStatusCode
        guard settings.regenerateXcodeProject else { return retCode }
        guard retCode == 0 else { return retCode }
        var generateXcodeProj: Bool = false
        // If the swift package udpate command returns text 'Removing', 'Cloning', 'Fetching', or 'Resolving' that means that the package was updated
        // And we need to re-genreate the xcode project
        let output = response.output ?? ""
        if output.contains("Removing") ||
           output.contains("Cloning") ||
           output.contains("Fetching") ||
           output.contains("Resolving") {
            generateXcodeProj = true
        }
        
        if !generateXcodeProj {
            do {
                
                // Get the package name
                let pkgDetails = try PackageDescription(swiftCommand: settings.swiftCommand,
                                                        packagePath: self.currentProjectPath,
                                                        loadDependencies: false,
                                                        console: self.console)
                    
                    
                let pkgName = pkgDetails.name
                    
                    let xcodeProjPath = self.currentProjectPath.appendingComponent(pkgName + ".xcodeproj")
                
                    if !xcodeProjPath.exists() {
                        // Xcode Project does not currently exist, lets set marker to create it
                        generateXcodeProj = true
                    } else {
                        func isPackageFileName(_ fileName: FSPath) -> Bool {
                            let lowerFileName = fileName.lastComponent.lowercased()
                            if lowerFileName == "package.swift" {
                                return true
                            }
                            if lowerFileName.hasPrefix("package@") &&
                               lowerFileName.hasSuffix(".swift") {
                                return true
                            }
                            
                            return false
                        }
                        
                        // Get all the modification dates of the different Package.swift files
                        if let packageModdates = (try? self.currentProjectPath.contentsOfDirectory())?
                            .filter(isPackageFileName)
                            .compactMap( { return $0.safely.modificationDate() } ) {
                            
                            if let xcodeModDate = xcodeProjPath.safely.modificationDate(),
                               let pbxprojModDate = xcodeProjPath.appendingComponent("project.pbxproj").safely.modificationDate() {
                                if packageModdates.contains(where: { return $0 > xcodeModDate || $0 > pbxprojModDate }) {
                                    // We found one of the Package.swift files is newer then the
                                    // Xcode Proj folder or the project.pbxproj file so we need to re-generate
                                    generateXcodeProj = true
                                }
                            } else {
                                // We could not get the modification date of the
                                // Xcode Proj so we assume we need to re-generate
                                generateXcodeProj = true
                            }
                                
                        } else {
                            // We could not get the modification dates of the
                            // Package.swift files.  So we assume we need to re-generate
                            generateXcodeProj = true
                        }
                    }
               
                
            } catch { }
        }
        
        guard generateXcodeProj else {
            return retCode
        }
        
        return try parent.execute(["package", "generate-xcodeproj"],
                                  environment: environment,
                                  currentDirectory: currentDirectory)
    }
    
    /// swift package generate-xcodeproj catcher
    public func commandPackageGenXcodeProj(_ parent: CLICommandGroup,
                                           _ argumentStartingAt: Int,
                                           _ arguments: [String],
                                           _ environment: [String: String]?,
                                           _ currentDirectory: URL?,
                                           _ userInfo: [String: Any],
                                           _ stackTrace: CodeStackTrace,
                                           _ exitStatusCode: Int32) throws -> Int32 {
        guard exitStatusCode == 0 else { return exitStatusCode }
        guard (arguments.firstIndex(of: "--help") == nil &&
               arguments.firstIndex(of: "-h") == nil) else { return exitStatusCode }
        
        var returnCode: Int32 = 0
        self.console.printVerbose("Loading package details", object: self)
        let packageDetails = try PackageDescription(swiftCommand: settings.swiftCommand,
                                                    packagePath: self.currentProjectPath,
                                                    loadDependencies: false,
                                                    console: self.console)
        self.console.printVerbose("Package details loaded", object: self)
        
        let packagePath = self.currentProjectPath.resolvingSymlinks
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectPath = packagePath.appendingComponent("\(packageDetails.name).xcodeproj")
        
        guard xCodeProjectPath.exists() else {
            self.console.printError("Project not found. \(xCodeProjectPath.string)", object: self)
            return 1
        }
        self.console.printVerbose("Loading Xcode project", object: self)
        let xcodeProject = try XcodeProject(fromURL: xCodeProjectPath.url)
        self.console.printVerbose("Loaded Xcode project", object: self)
        
        // Only add build rule if we have supported files
        if (try settings.whenToAddBuildRules.canAddBuildRules(packagePath,
                                                              generator: generator)) {
            for tD in packageDetails.targets {
                //guard tD.type.lowercased() != "test" else { continue }
                let relativePath = tD.path.relativePath(to: currentProjectPath)
                if let t = xcodeProject.targets.first(where: { return $0.name == tD.name }),
                    let nT = t as? XcodeNativeTarget,
                   let targetGroup = xcodeProject.resources.group(atPath: relativePath.string)  {
                    //let targetGroup = xcodeProject.resources.group(atPath: "Sources/\(tD.name)")!
                    let rCode = try addDSwiftFilesToTarget(in: XcodeFileSystemURLResource(directory: tD.path.string),
                                               inGroup: targetGroup,
                                               havingTarget: nT,
                                                           usingProvider: xcodeProject.fsProvider,
                                                           using: .default)
                    if rCode != 0 {
                        returnCode = rCode
                    }
                    
                   
                    let supportedFilePatterns: String =  generator.supportedExtensions.map({ return "*.\($0)"}).joined(separator: " ")
                    let rule = try nT.createBuildRule(name: "Dynamic Swift",
                                                            compilerSpec: "com.apple.compilers.proxy.script",
                                                            fileType: XcodeFileType.Pattern.proxy,
                                                            editable: true,
                                                            filePatterns: supportedFilePatterns,
                                                            outputFiles: ["$(INPUT_FILE_DIR)/$(INPUT_FILE_BASE).swift"],
                                                            outputFilesCompilerFlags: nil,
                                                            script: "",
                                                            atLocation: .end)
                    rule.script = """
                    if ! [ -x "$(command -v \(dSwiftAppName))" ]; then
                        echo "Error: \(dSwiftAppName) is not installed.  Please visit \(dSwiftURL) to download and install." >&2
                        exit 1
                    fi
                    \(dSwiftAppName) xcodebuild ${INPUT_FILE_PATH}
                    """
                   
                }
            }
        }
 
        if settings.includeSwiftLintInXcodeProject == .always ||
            (settings.includeSwiftLintInXcodeProject == .whenAvailable && Commands.which("swiftlint") != nil) {
            for tD in packageDetails.targets {
                //guard tD.type.lowercased() != "test" else { continue }
                if let t = xcodeProject.targets.first(where: { $0.name == tD.name}),
                    let nT = t as? XcodeNativeTarget  {
                    
                    let rule = try nT.createShellScriptBuildPhase(name: "SwiftLint",
                                                                  atLocation: .end)
                    rule.shellScript = """
                    # Type a script or drag a script file from your workspace to insert its path.
                    if which swiftlint >/dev/null; then
                      swiftlint
                    else
                      echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
                    fi
                    """
                }
            }
        }
 
        if settings.xcodeResourceSorting == .sorted {
            xcodeProject.resources.sort()
        }
        
        var indexAfterLastPackagFile: Int = 1
        
        
        var children = try xcodeProject.fsProvider.contentsOfDirectory(at: xcodeProject.projectFolder)
        children.sort(by: { return $0.path < $1.path})
        for child in children {
            let fileName = child.lastPathComponent
            if fileName.hasPrefix("Package@swift-") && fileName.hasSuffix(".swift") {
                var packageVersion: String = fileName
                packageVersion.removeFirst("Package@swift-".count)
                packageVersion.removeLast(".swift".count)
                if let _ = Double(packageVersion) {
                    if xcodeProject.resources.file(atPath: child.lastPathComponent) == nil {
                        self.console.printVerbose("Adding \(fileName) to project file", object: self)
                        try xcodeProject.resources.addExisting(child,
                                                               atLocation: .index(indexAfterLastPackagFile),
                                                               savePBXFile: false)
                        indexAfterLastPackagFile += 1
                    }
                }
            }
        }
        
        // Add additional files
        let additionalFiles: [FSRelativePath] = ["LICENSE.md", "README.md", "Tests/LinuxMain.swift"]
        for file in additionalFiles {
            let filePath = xcodeProject.projectFolder.appendingFileComponent(file.string)
            if try xcodeProject.fsProvider.itemExists(at: filePath) {
                var group: XcodeGroup = xcodeProject.resources
                var usingRootGroup: Bool = true
                // If we find that the file is in a sub folder we must find the sub group
                if file.components.count > 1 {
                    let groupPath = file.deletingLastComponent()
                    guard let grp = xcodeProject.resources.group(atPath: groupPath.string) else {
                        self.console.printError("Unable to find group '\(groupPath)' to add file \(file.lastComponent)", object: self)
                        continue
                    }
                    usingRootGroup = false
                    group = grp
                }
                
                if group.file(atPath: file.lastComponent) == nil {
                    var addLocation: AddLocation<XcodeFileResource> = .end
                    if usingRootGroup {
                        addLocation = .index(indexAfterLastPackagFile)
                        indexAfterLastPackagFile += 1
                    }
                    try group.addExisting(filePath, atLocation: addLocation, savePBXFile: false)
                }
                
                
            }
        }
        
        let removeReferences: [FSRelativePath] = ["DerivedData", "build"]
        for reference in removeReferences {
            let referencePath = xcodeProject.projectFolder.appendingFileComponent(reference.string)
            if try xcodeProject.fsProvider.itemExists(at: referencePath) {
                var group: XcodeGroup = xcodeProject.resources
                // If we find that the file is in a sub folder we must find the sub group
                if reference.components.count > 1 {
                    let groupPath = reference.deletingLastComponent()
                    guard let grp = xcodeProject.resources.group(atPath: groupPath.string) else {
                        self.console.printError("Unable to find group '\(groupPath)' to remove file \(reference.lastComponent)", object: self)
                        continue
                    }
                    group = grp
                }
                
                if let resource = group.resource(atPath: reference.lastComponent) {
                    try resource.remove(deletingFiles: false, savePBXFile: false)
                }
            }
        }
        
        //debugPrint(xcodeProject)
        try xcodeProject.save()
    
        return returnCode
    }
    
    /// Adds dswift files to Xcode Project
    internal func addDSwiftFilesToTarget(in url: XcodeFileSystemURLResource,
                                         inGroup group: XcodeGroup,
                                         havingTarget target: XcodeTarget,
                                         usingProvider provider: XcodeFileSystemProvider,
                                         using fileManager: FileManager) throws -> Int32 {
        func hasDSwiftSubFiles(in url: XcodeFileSystemURLResource, usingProvider provider: XcodeFileSystemProvider) throws -> Bool {
            let children = try provider.contentsOfDirectory(at: url)

            for child in children {
                // Check current dir for files
                if child.isFile && generator.isSupportedFile(child) {
                    return true
                }
            }
            for child in children {
                // Check sub dir for files
                if child.isDirectory {
                    if (try hasDSwiftSubFiles(in: child,
                                              usingProvider: provider)) { return true }
                }
            }
            return false
        }
        
        var rtn: Int32 = 0
        
        let children = try provider.contentsOfDirectory(at: url)
        
        for child in children {
            
            if child.isFile && generator.canAddToXcodeProject(file: child) {
                if !(try generator.updateXcodeProject(xcodeFile: child,
                                                      inGroup: group,
                                                      havingTarget: target,
                                                      includeGeneratedFilesInXcodeProject: settings.includeGeneratedFilesInXcodeProject,
                                                      using: fileManager)) {
                    rtn = 1
                }
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
                                                       usingProvider: provider,
                                                       using: fileManager)
                
                if rtn == 0 && rCode > 0 { rtn = rCode }
            }
        }
        
        return rtn
        
    }
    
    /// swift package init catcher
    public func commandPackageInitPreSwift(_ parent: CLICommandGroup,
                                           _ argumentStartingAt: Int,
                                           _ arguments: inout [String],
                                           _ environment: [String: String]?,
                                           _ currentDirectory: URL?,
                                           _ storage: inout [String: Any]?,
                                           _ userInfo: [String: Any],
                                           _ stackTrace: CodeStackTrace) throws -> Int32 {
        
        let noDSwift = arguments.contains(where: { $0.lowercased() == "--nodswift" })
        if noDSwift { arguments.removeAll(where: { $0.lowercased() == "--nodswift" }) }
        if storage == nil {
            storage = [:]
        }
        storage!["noDswift"] = noDSwift
        return 0
    }
    /// swift package init catcher
    public func commandPackageInitPostSwift(_ parent: CLICommandGroup,
                                            _ argumentStartingAt: Int,
                                            _ arguments: [String],
                                            _ environment: [String: String]?,
                                            _ currentDirectory: URL?,
                                            _ storage: [String: Any]?,
                                            _ userInfo: [String: Any],
                                            _ stackTrace: CodeStackTrace,
                                            _ exitStatusCode: Int32) throws -> Int32 {
        let noDSwift = ((storage ?? [:])["noDswift"] as? Bool) ?? false
        var exitStatusCode = exitStatusCode
        guard exitStatusCode == 0 else { return exitStatusCode }
        guard (arguments.firstIndex(of: "--help") == nil &&
               arguments.firstIndex(of: "-h") == nil) else { return exitStatusCode }
        
        let packageType: String = {
            guard let typeParamIndex = arguments.firstIndex(where: { return ($0.lowercased() == "--type" ) }) else { return "" }
            guard typeParamIndex < arguments.count - 1 else { return "" }
            return arguments[typeParamIndex + 1]
        }()
        
        if let toolVer = settings.defaultPackageInitToolsVersion,
           let ver = Version.SingleVersion(toolVer) {
            // There were changes to the Package Manager on how Package.swift is generated
            // and new objects are used which aren't backwards compatible
            let baseChangeVer: Version.SingleVersion = "5.4"
            if !(self.swiftVersion >= baseChangeVer && ver < baseChangeVer) {
                // Set package tool-version
                _ = try? parent.execute(["package", "tools-version", "--set", toolVer],
                                        environment: environment,
                                        currentDirectory: currentDirectory)
            }
        }
        
        try settings.writeReadMe(to: self.currentProjectPath.appendingComponent("README.md"),
                                 for: packageType.lowercased(),
                                 withName: self.currentProjectPath.lastComponent,
                                 includeDSwiftMessage: !noDSwift,
                                 dswiftInfo: self.dswiftInfo,
                                 currentProjectPath: self.currentProjectPath,
                                 console: self.console)
        
        /// Setup license file
        try settings.writeLicense(to: self.currentProjectPath.appendingComponent("LICENSE.md"),
                                  console: self.console)
        
        let gitIgnorePath = self.currentProjectPath.appendingComponent(".gitignore")
        
        var workingGitIgnoreFile = settings.defaultGitIgnore ?? GitIgnoreFile.default
        if let gitIgnoreAdditions = settings.gitIgnoreAdditions {
            // Add Config git ignore additions
            workingGitIgnoreFile += gitIgnoreAdditions
        }
        var isUpdatingGitIgnore: Bool = false
        if gitIgnorePath.exists() {
            isUpdatingGitIgnore = true
            do {
                let currentGitIgnore = try GitIgnoreFile(at: gitIgnorePath)
                // Add existing gitignore settings
                workingGitIgnoreFile += currentGitIgnore
            } catch {
                self.console.printError("Unable to read existing .gitignore")
            }
        }
        
        do {
            if isUpdatingGitIgnore { self.console.print("Updating .gitignore") }
            else { self.console.print("Adding .gitignore") }
            try workingGitIgnoreFile.save(to: gitIgnorePath)
        } catch {
            if isUpdatingGitIgnore { self.console.printError("Failed to update .gitignore") }
            else { self.console.printError("Failed to add .gitignore") }
            self.console.printError(error)
        }
        
        if self.supportsXcodeProjGen {
            let genXcodeProj: Bool = settings.generateXcodeProjectOnInit.canGenerated(forName: arguments.last!.lowercased())
            
            if genXcodeProj {
                self.console.print("Generating Xcode Project")
                
                exitStatusCode = try parent.execute(["package", "generate-xcodeproj"],
                                                    environment: environment,
                                                    currentDirectory: currentDirectory)
            }
        }
        
        
        return exitStatusCode
    }
    
    public func commandCompletionToolsBash(_ parent: CLICommandGroup,
                                           _ argumentStartingAt: Int,
                                           _ arguments: [String],
                                           _ environment: [String: String]?,
                                           _ currentDirectory: URL?,
                                           _ response: CLICapturedStringResponse,
                                           _ userInfo: [String: Any],
                                           _ stackTrace: CodeStackTrace) throws -> Int32 {
        guard var out = response.output else {
            return 1
        }
        
        if let start = out.range(of: "_swift()"),
           let endOfStart = out.range(of: "}", range: start.upperBound..<out.endIndex) {
            let replacement: String = """
            _swift()
            {
                declare -a cur prev
                cur="${COMP_WORDS[COMP_CWORD]}"
                prev="${COMP_WORDS[COMP_CWORD-1]}"

                COMPREPLY=()
                if [[ $COMP_CWORD == 1 ]]; then
                    _swift_compiler
                    COMPREPLY+=( $(compgen -W "build run package test" -- $cur) )
                    return
                fi
                case ${COMP_WORDS[1]} in
                    (build)
                        _swift_build 2
                        ;;
                    (run)
                        _swift_run 2
                        ;;
                    (package)
                        _swift_package 2
                        ;;
                    (test)
                        _swift_test 2
                        ;;
                esac
            }
            """
            out.replaceSubrange(start.lowerBound..<endOfStart.upperBound, with: replacement)
        }
        out = out.replacingOccurrences(of: "_swift", with: "_\(self.dSwiftAppName)")
        out = out.replacingOccurrences(of: "complete -F _\(self.dSwiftAppName) swift",
                                       with: "complete -F _\(self.dSwiftAppName) \(self.dSwiftAppName)")
        out = out.replacingOccurrences(of: "COMPREPLY=( $(compgen -W \"--type\" -- $cur) )",
                                       with: "COMPREPLY=( $(compgen -W \"--noDSwift --type\" -- $cur) )")
        
        self.console.print(out)
        return 0
    }
    
    private func patchZSHCompletionScript(_ script: String) -> String {
        var script = script
        if let start = script.range(of: "_swift()"),
           let endOfStart = script.range(of: "}", range: start.upperBound..<script.endIndex) {
            let replacement: String = """
            _swift() {
                _arguments -C \
                    '(- :)--help[prints the synopsis and a list of the most commonly used commands]: :->arg' \
                    '(-): :->command' \
                    '(-)*:: :->arg' && return

                case $state in
                    (command)
                        local tools
                        tools=(
                            'build:build sources into binary products'
                            'run:build and run an executable product'
                            'package:perform operations on Swift packages'
                            'test:build and run tests'
                        )
                        _alternative \
                            'tools:common:{_describe "tool" tools }' \
                            'compiler: :_swift_compiler' && _ret=0
                        ;;
                    (arg)
                        case ${words[1]} in
                            (build)
                                _swift_build
                                ;;
                            (run)
                                _swift_run
                                ;;
                            (package)
                                _swift_package
                                ;;
                            (test)
                                _swift_test
                                ;;
                        esac
                        ;;
                esac
            }
            """
            script.replaceSubrange(start.lowerBound..<endOfStart.upperBound, with: replacement)
        }
        script = script.replacingOccurrences(of: "_swift", with: "_\(self.dSwiftAppName)")
        
        return script
    }
    
    public func commandCompletionToolsZSH(_ parent: CLICommandGroup,
                                       _ argumentStartingAt: Int,
                                       _ arguments: [String],
                                       _ environment: [String: String]?,
                                       _ currentDirectory: URL?,
                                       _ response: CLICapturedStringResponse,
                                          _ userInfo: [String: Any],
                                          _ stackTrace: CodeStackTrace) throws -> Int32 {
        guard var out = response.output else {
            return 1
        }
        
        out = self.patchZSHCompletionScript(out)
        
        self.console.print(out)
        return 0
        
    }
    
    public func commandCompletionToolsFish(_ parent: CLICommandGroup,
                                           _ argumentStartingAt: Int,
                                           _ arguments: [String],
                                           _ environment: [String: String]?,
                                           _ currentDirectory: URL?,
                                           _ response: CLICapturedStringResponse,
                                           _ userInfo: [String: Any],
                                           _ stackTrace: CodeStackTrace) throws -> Int32 {
        guard var out = response.output else {
            return 1
        }

        out = out.replacingOccurrences(of: "complete -c swift -n",
                                       with: "complete -c _\(self.dSwiftAppName) -n")
        out = out.replacingOccurrences(of: "__fish_swift_using_command swift",
                                       with: "__fish_\(self.dSwiftAppName)_using_command \(self.dSwiftAppName)")
        self.console.print(out)
        return 0
    }
    
    public func commandGenerateCompletionScript(_ parent: CLICommandGroup,
                                                _ argumentStartingAt: Int,
                                                _ arguments: [String],
                                                _ environment: [String: String]?,
                                                _ currentDirectory: URL?,
                                                _ response: CLICapturedStringResponse,
                                                _ userInfo: [String: Any],
                                                _ stackTrace: CodeStackTrace) throws -> Int32 {
        
        if arguments.contains(where: { return $0.lowercased() == "bash" } ) {
            
            return try commandCompletionToolsBash(parent,
                                                  argumentStartingAt,
                                                  arguments,
                                                  environment,
                                                  currentDirectory,
                                                  response,
                                                  userInfo,
                                                  stackTrace.stacking())
            
               
        } else if arguments.contains(where: { return $0.lowercased() == "zsh" } ) {
            return try commandCompletionToolsZSH(parent,
                                                 argumentStartingAt,
                                                 arguments,
                                                 environment,
                                                 currentDirectory,
                                                 response,
                                                 userInfo,
                                                 stackTrace.stacking())
        } else {
            return try parent.executeHelp(argumentStartingAt: argumentStartingAt,
                                          arguments: arguments,
                                          environment: environment,
                                          currentDirectory: currentDirectory,
                                          withMessage: "Missing flavour 'bash' or 'zsh'",
                                          userInfo: userInfo,
                                          stackTrace: stackTrace.stacking())
        }
    }
    
    private func commandPackageInstallAutoScript(_ parent: CLICommandGroup,
                                                _ argumentStartingAt: Int,
                                                _ arguments: [String],
                                                _ environment: [String: String]?,
                                                _ currentDirectory: URL?,
                                                 genScriptCommand: String,
                                                 bashFlavour: String,
                                                 zshFlavour: String,
                                                 userInfo: [String: Any],
                                                 stackTrace: CodeStackTrace) throws -> Int32 {
        if arguments.last == "bash"  {
            var bashProfile: StringFile
            do {
                self.console.print("Opening Bash Profile")
                bashProfile = try StringFile("~/.bash_profile")
                self.console.print("Opened Bash Profile")
            }
            catch {
                self.console.printError("Unable to load ~/.bash_profile", object: self)
                return 1
            }
            guard !bashProfile.contains("which \(dSwiftAppName)") else {
                self.console.print("Autocomplete script was previously installed")
                return 0
            }
            
            if let startScript = bashProfile.range(of: "# Source \(self.dSwiftModuleName) completion"),
               let rangeOfIfBegin = bashProfile.range(of: "if [ -n \"`which \(self.dSwiftAppName)`\" ]; then", range: startScript.upperBound..<bashProfile.endIndex),
               let endScript = bashProfile.range(of: "fi", range: rangeOfIfBegin.upperBound..<bashProfile.endIndex) {
                self.console.print("Autocomplete script was previously installed.  Removing old copy")
                bashProfile.removeSubrange(startScript.lowerBound..<endScript.upperBound)
            }
            self.console.print("Adding \(self.dSwiftModuleName) to Bash Profile")
            bashProfile += """
            
            # Source \(self.dSwiftModuleName) completion
            if [ -n "`which \(self.dSwiftAppName)`" ]; then
            eval "`\(self.dSwiftAppName) package \(genScriptCommand) \(bashFlavour)`"
            fi
            """
            
            do {
                self.console.print("Saving Bash Profile")
                try bashProfile.save()
                self.console.print("Bash Profile Saved")
                
            } catch {
                self.console.printError("Unable to save ~/.bash_profile", object: self)
                return 1
            }
            
            self.console.print("Autocomplete script installed.  Please run source ~/.bash_profile", object: self)
            
            return 0
        } else if arguments.last == "zsh" {
            
            let scriptResp = try parent.cli.waitAndCaptureStringResponse(arguments: ["package",
                                                                                     genScriptCommand,
                                                                                     zshFlavour],
                                                                         environment: environment,
                                                                         currentDirectory: currentDirectory,
                                                                         outputOptions: .captureAll,
                                                                         userInfo: userInfo,
                                                                         stackTrace: stackTrace.stacking())
            
            guard let script = scriptResp.output else {
                self.console.printError("Unable to retrieve zsh completeion script")
                return 1
            }
            
            guard scriptResp.exitStatusCode == 0 else {
                self.console.printError(script)
                return scriptResp.exitStatusCode
            }
            
            
            let zshScript = patchZSHCompletionScript(scriptResp.output ?? "")
            
            if let omzshPath = ProcessInfo.processInfo.environment["ZSH"] {
                var autocompletePath = omzshPath
                if !autocompletePath.hasSuffix("/") { autocompletePath += "/" }
                autocompletePath += "completions/"
                let autoScriptPath = autocompletePath + "_" + dSwiftAppName
                
                if FileManager.default.fileExists(atPath: autoScriptPath) {
                    self.console.print("Autocomplete script was previously installed in Oh-My-Zsh.  Removing old copy")
                    do {
                        try FileManager.default.removeItem(atPath: autoScriptPath)
                    } catch {
                        self.console.printError("Unable to delete \(autoScriptPath) script", object: self)
                        return 1
                    }
                }
                
                do { try zshScript.write(toFile: autoScriptPath, atomically: true, encoding: .utf8) }
                catch {
                    self.console.printError("Unable to save \(autoScriptPath)", object: self)
                    return 1
                }
                
                self.console.print("Autocomplete script installed into Oh-My-Zsh.  Please start a new session")
                
                return 0
                
            } else {
            
                let zshFolderPath: String = NSString(string: "~/.zsh").expandingTildeInPath
                
                if !FileManager.default.fileExists(atPath: zshFolderPath) {
                    do {
                        try FileManager.default.createDirectory(atPath: zshFolderPath, withIntermediateDirectories: false, attributes: nil)
                    } catch {
                        self.console.printError("Unable to create ~/.zsh folder", object: self)
                        return 1
                    }
                }
                
                let zshProfilePath: String = NSString(string: "~/.zsh/_\(dSwiftAppName)").expandingTildeInPath
                if FileManager.default.fileExists(atPath: zshProfilePath) {
                    self.console.print("Autocomplete script was previously installed.  Removing old copy")
                    do {
                        try FileManager.default.removeItem(atPath: zshProfilePath)
                    } catch {
                        self.console.printError("Unable to delete ~/.zsh/_\(dSwiftAppName) script", object: self)
                        return 1
                    }
                }
                
                do { try zshScript.write(toFile: zshProfilePath, atomically: true, encoding: .utf8) }
                catch {
                    self.console.printError("Unable to save ~/.zsh/_\(dSwiftAppName)", object: self)
                    return 1
                }
                
                
                var zshProfile: StringFile
                do { zshProfile = try StringFile("~/.zshrc") }
                catch {
                    self.console.printError("Unable to load ~/.zshrc", object: self)
                    return 1
                }
                
                guard !zshProfile.contains("fpath=(~/.zsh $fpath)") else {
                    self.console.print("Autocomplete script installed.  Please run compinit", object: self)
                    return 0
                }
                
                zshProfile += "fpath=(~/.zsh $fpath)\n"
                
                do { try zshProfile.save() }
                catch {
                    self.console.printError("Unable to save ~/.zshrc", object: self)
                    return 1
                }
                
                self.console.print("Autocomplete script installed.  Please run compinit", object: self)
                
                return 0
            }
         } else if arguments.last == "--help" || arguments.last == "-h" {
            let msg: String = """
            OVERVIEW: Install completion script (Bash or ZSH)

            COMMANDS:
              flavor   Shell flavor (bash or zsh)
            """
            self.console.print(msg)
            return 0
        } else {
            if arguments.last! != "install-completion-script" {
                self.console.printError("error: unknown value '\(arguments.last!)' for argument flavor; use --help to print usage", object: self)
            } else {
                self.console.printError("error: missing flavor; use --help to print usage", object: self)
            }
            return 1
        }
    }
    
    /// swift package generate-xcodeproj catcher
    public func commandPackageInstallAutoScriptGenCompletionScript(_ parent: CLICommandGroup,
                                                                   _ argumentStartingAt: Int,
                                                                   _ arguments: [String],
                                                                   _ environment: [String: String]?,
                                                                   _ currentDirectory: URL?,
                                                                   _ standardInput: Any?,
                                                                   _ userInfo: [String: Any],
                                                                   _ stackTrace: CodeStackTrace) throws -> Int32 {
        
        return try commandPackageInstallAutoScript(parent,
                                                   argumentStartingAt,
                                                   arguments,
                                                   environment,
                                                   currentDirectory,
                                                   genScriptCommand: "generate-completion-script",
                                                   bashFlavour: "bash",
                                                   zshFlavour: "zsh",
                                                   userInfo: userInfo,
                                                   stackTrace: stackTrace.stacking())
        
    }
    
    /// swift package generate-xcodeproj catcher
    public func commandPackageInstallAutoScriptCompletionTool(_ parent: CLICommandGroup,
                                                              _ argumentStartingAt: Int,
                                                              _ arguments: [String],
                                                              _ environment: [String: String]?,
                                                              _ currentDirectory: URL?,
                                                              _ standardInput: Any?,
                                                              _ userInfo: [String: Any],
                                                              _ stackTrace: CodeStackTrace) throws -> Int32 {
        
        return try commandPackageInstallAutoScript(parent,
                                                   argumentStartingAt,
                                                   arguments,
                                                   environment,
                                                   currentDirectory,
                                                   genScriptCommand: "completion-tool",
                                                   bashFlavour: "generate-bash-script",
                                                   zshFlavour: "generate-zsh-script",
                                                   userInfo: userInfo,
                                                   stackTrace: stackTrace.stacking())
        
    }
}
