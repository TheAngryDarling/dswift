//
//  StaticFileSourceCodeGenerator.swift
//  dswift
//
//  Created by Tyler Anger on 2019-09-12.
//

import Foundation
import XcodeProj


public class StaticFileSourceCodeGenerator: DynamicGenerator {
    
    
    public enum Errors: Error, CustomStringConvertible {
        
        case missingSource(atPath: String)
        case couldNotCleanFolder(atPath: String, Swift.Error?)
        case unableToGenerateSource(for: String, Swift.Error?)
        case unableToWriteFile(atPath: String, Swift.Error?)
        
        case mustBeFileURL(URL)
        
        public var description: String {
            switch self {
            
            case .missingSource(atPath: let path): return "Missing source file '\(path)'"
            case .couldNotCleanFolder(atPath: let path, let err):
                var rtn: String = "Could not clean compiled dswift static files from '\(path)'"
                if let e = err { rtn += ": \(e)" }
                return rtn
            case .unableToGenerateSource(for: let path, let err):
                var rtn: String = "Unable to compile dswift static file '\(path)'"
                if let e = err {
                    if e is StaticFileSourceCodeGenerator.Errors {
                        rtn = "\(e)"
                    } else {
                        rtn += ": \(e)"
                    }
                }
                return rtn
            case .unableToWriteFile(atPath: let path, let err):
                var rtn: String = "Unable to write file '\(path)'"
                if let e = err { rtn += ": \(e)" }
                return rtn
            case .mustBeFileURL(let url):
                return "URL '\(url)' must be a file url"
            }
        }
    }
    
    fileprivate struct StaticFile: Codable {
        public enum FileType {
            case text(String.Encoding)
            case binary
            
            public var isText: Bool {
                guard case .text(_) = self else { return false }
                return true
            }
            public var textEncoding: String.Encoding? {
                guard case .text(let enc) = self else { return nil }
                return enc
            }
            public var isBinary: Bool {
                guard case .binary = self else { return false }
                return true
            }
        }
        public enum Modifier: String, Codable {
            case `public`
            case `internal`
        }
        let file: String
        let modifier: Modifier
        let name: String
        let namespace: String?
        let type: FileType
        
    }
    
    public var supportedExtensions: [String] { return ["dswift-static"] }
    
    private let _print: PRINT_SIG
    private let _verbosePrint: PRINT_SIG
    private let _debugPrint: PRINT_SIG
    
    required public init(_ swiftPath: String,
                         _ dSwiftModuleName: String,
                         _ dSwiftURL: String,
                         _ print: @escaping PRINT_SIG,
                         _ verbosePrint: @escaping PRINT_SIG,
                         _ debugPrint: @escaping PRINT_SIG) throws {
        
        self._print = print
        self._verbosePrint = verbosePrint
        self._debugPrint = debugPrint
    }
    
    internal func print(_ items: Any...,
                        separator: String = " ",
                        terminator: String = "\n",
                        filename: String = #file,
                        line: Int = #line,
                        funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._print(msg + terminator, filename, line, funcname)
    }
    
    internal func verbosePrint(_ items: Any...,
                                separator: String = " ",
                                terminator: String = "\n",
                                filename: String = #file,
                                line: Int = #line,
                                funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._verbosePrint(msg + terminator, filename, line, funcname)
    }
    
    internal func debugPrint(_ items: Any...,
                            separator: String = " ",
                            terminator: String = "\n",
                            filename: String = #file,
                            line: Int = #line,
                            funcname: String = #function) {
        let msg: String  = items.reduce("") {
            var rtn: String = $0
            if !rtn.isEmpty { rtn += separator }
            rtn += "\($1)"
            return rtn
        }
        self._debugPrint(msg + terminator, filename, line, funcname)
    }
    
    func isSupportedFile(_ file: String) -> Bool {
        return self.supportedExtensions.contains(file.pathExtension.lowercased())
    }
    
    public func languageForXcode(file: String) -> String? {
        return nil
    }
    
    public func explicitFileTypeForXcode(file: String) -> XcodeFileType? {
        return XcodeFileType.Text.json
    }
    
    public func requiresSourceCodeGeneration(for source: String) throws -> Bool {
        let source = URL(fileURLWithPath: source)
        let staticFile: StaticFile = try JSONDecoder().decode(StaticFile.self,
                                                           from: try Data(contentsOf: source))
        let staticFilePath = staticFile.file.fullPath(from: source.deletingLastPathComponent().path)
        let staticFileURL = URL(fileURLWithPath: staticFilePath)
        
        let destination = try generatedFilePath(for: source)
        
        // If the generated file does not exist, then return true
        guard FileManager.default.fileExists(atPath: destination.path) else {
            verbosePrint("Generated file '\(destination.path)' does not exists")
            return true
        }
        // Get the modification dates otherwise return true to rebuild
        guard let srcMod = source.pathModificationDate,
              let staticSrcMod = staticFileURL.pathModificationDate,
              let desMod = destination.pathModificationDate else {
                verbosePrint("Wasn't able to get all modification dates")
            return true
        }
        // Source or static file is newer than destination, meaning we must rebuild
        guard srcMod <= desMod && staticSrcMod <= desMod else {
            if srcMod > desMod {
                verbosePrint("'\(source.path)' is newer")
            } else  if staticSrcMod > desMod {
                verbosePrint("'\(staticFileURL.path)' is newer")
            }
            return true
        }
        var enc: String.Encoding = .utf8
        let fileContents = try String(contentsOf: destination, foundEncoding: &enc)
        if fileContents.contains("// Failed to generate source code.") { return true }
        return false
    }
    
    public func updateXcodeProject(xcodeFile: XcodeFileSystemURLResource,
                                  inGroup group: XcodeGroup,
                                  havingTarget target: XcodeTarget) throws -> Bool {
        var rtn: Bool = false
        verbosePrint("Calling \(type(of: self)).updateXcodeProject")
        let staticFilePath: String? = {
            do {
                let source = URL(fileURLWithPath: xcodeFile.path)
                let staticFile: StaticFile = try JSONDecoder().decode(StaticFile.self,
                                                                      from: try Data(contentsOf: source))
                return staticFile.file.fullPath(from: xcodeFile.path.deletingLastPathComponent)
            } catch {
                return nil
            }
        }()
        
        if group.file(atPath: xcodeFile.lastPathComponent) == nil {
            // Only add the dswift file to the project if its not already there
            let f = try group.addExisting(xcodeFile,
                                          copyLocally: true,
                                          savePBXFile: false) as! XcodeFile
            
            //f.languageSpecificationIdentifier = "xcode.lang.swift"
            f.languageSpecificationIdentifier = self.languageForXcode(file: xcodeFile.path)
            f.explicitFileType = self.explicitFileTypeForXcode(file: xcodeFile.path)
            target.sourcesBuildPhase().createBuildFile(for: f)
            //print("Adding dswift file '\(child.path)'")
            rtn = true
        }
        if let sFile = staticFilePath {
            verbosePrint("Found static file '\(sFile)' for adding to project")
            
            if !FileManager.default.fileExists(atPath: sFile) {
                errPrint("WARNING: Static file '\(sFile)' does not exist.")
            }
    
            let rootGroupPath = group.mainGroup.fullPath
            if let r = sFile.range(of: rootGroupPath), r.lowerBound == sFile.startIndex {
                var staticFileRelativePath = String(sFile[r.upperBound...])
                if !staticFileRelativePath.hasPrefix("/") { staticFileRelativePath = "/" + staticFileRelativePath }
                let staticFileParentPath = staticFileRelativePath.deletingLastPathComponent
                let staticFileParentGroup: XcodeGroup = try group.mainGroup.subGroup(atPath: staticFileParentPath,
                                                                                     options: .createOnly)!
                if !staticFileParentGroup.contains(where: { $0.name == sFile.lastPathComponent }) {
                    verbosePrint("Adding '\(staticFileRelativePath)' to project")
                    try staticFileParentGroup.addExisting(XcodeFileSystemURLResource(file: sFile),
                                                          copyLocally: true,
                                                          savePBXFile: false)
                    rtn = true
                }
            } else {
                errPrint("ERROR: Static file '\(sFile)' is not within the project")
            }
            
        } else {
            errPrint("ERROR: Could not load path for static file in '\(xcodeFile.path)'")
        }
        let swiftName = try self.generatedFilePath(for: xcodeFile.path).lastPathComponent
        if let f = group.file(atPath: swiftName) {
            
            //let source = try String(contentsOf: URL(fileURLWithPath: f.fullPath), encoding: f.encoding ?? .utf8)
            let source: String = try {
                if let e = f.encoding {
                    return try String(contentsOf: URL(fileURLWithPath: f.fullPath), encoding: e)
                } else {
                    var srcEnc: String.Encoding = .utf8
                    return try String(contentsOf: URL(fileURLWithPath: f.fullPath), foundEncoding: &srcEnc)
                }
            }()
            // Make sure we are working with a generated file
            if source.hasPrefix("//  This file was dynamically generated from") {
               if !settings.includeGeneratedFilesInXcodeProject {
                   try f.remove(deletingFiles: false, savePBXFile: false)
               } else {
                   // Remove target membership for file
                   target.remove(file: f, from: .sourceBuildPhase)
               }
               rtn = true
            }
            
        }
        return rtn
    }
    
    public func generateSource(from sourcePath: String,
                               havingEncoding encoding: String.Encoding? = nil) throws -> (source: String, encoding: String.Encoding) {
        
        guard FileManager.default.fileExists(atPath: sourcePath) else { throw Errors.missingSource(atPath: sourcePath) }
    
        let srcFile: StaticFile = try JSONDecoder().decode(StaticFile.self,
                                                           from: try Data(contentsOf: URL(fileURLWithPath: sourcePath)))
        
        var sourceCode: String = "//  This file was dynamically generated from '\(sourcePath.lastPathComponent)' and '\(srcFile.file)' by \(dSwiftModuleName).  Please do not modify directly.\n"
        
        sourceCode += "//  \(dSwiftModuleName) can be found at \(dSwiftURL).\n\n"
        
         sourceCode += "import Foundation\n\n"
        
        var structModified: String = "\(srcFile.modifier) "
        var structTabs: String = ""
        if let namespace = srcFile.namespace {
            structTabs = "\t"
            structModified = ""
            sourceCode += "\(srcFile.modifier) extension \(namespace) {\n\n"
        }
        
        let workingFile: String = srcFile.file.fullPath(from: sourcePath.deletingLastPathComponent)
        
        let workingFileURL = URL(fileURLWithPath: workingFile)
        var encoding: String.Encoding = srcFile.type.textEncoding ?? .utf8
        
        
        sourceCode += structTabs + "\(structModified)struct " + srcFile.name + " {\n"
        sourceCode += structTabs + "\tprivate init() { }\n"
        
        if srcFile.type.isText {
            
            //var stringValue = try String(contentsOf: workingFileURL, usedEncoding: &encoding)
            var stringValue: String
            if let enc = srcFile.type.textEncoding {
                stringValue = try String(contentsOf: workingFileURL, encoding: enc)
                encoding = enc
            } else {
                var enc: String.Encoding = .utf8
                stringValue = try String(contentsOf: workingFileURL, foundEncoding: &enc)
                encoding = enc
            }
            
            stringValue = stringValue.replacingOccurrences(of: "\\", with: "\\\\")
            sourceCode += structTabs + "\t\(srcFile.modifier) static let string: String = \"\"\"\n"
            sourceCode += "\(stringValue)"
            sourceCode += "\n"
            sourceCode += "\"\"\"\n"
            sourceCode += structTabs + "\t\(srcFile.modifier) static let encoding: String.Encoding = String.Encoding(rawValue: \(encoding.rawValue))\n"
            sourceCode += structTabs + "\t\(srcFile.modifier) static var data: Data { return \(srcFile.name).string.data(using: encoding)! }\n"
            
        } else {
            
             let data = try Data(contentsOf: workingFileURL)
            sourceCode += structTabs + "\tprivate static let _value: [UInt8] = [\n"
            sourceCode += structTabs + "\t\t"
            for (idx, val) in data.enumerated() {
                sourceCode += String(format: "0x%02X", val)
                if (idx < (data.count - 1)) { sourceCode += ", " }
                if idx > 0 && ((idx + 1) % 10) == 0 { sourceCode += "\n" + structTabs + "\t\t" }
                
            }
            sourceCode += "\n"
            sourceCode += structTabs + "\t]\n"
            sourceCode += structTabs + "\t\(srcFile.modifier) static var data: Data { return Data(\(srcFile.name)._value) }\n"
            
        }
        sourceCode += structTabs + "}"
        
        
        if let _ = srcFile.namespace {
            sourceCode += "\n\n}"
        }
        
        
        
        
        return (source: sourceCode, encoding: encoding)
        
    }
    
    
    
    public func generateSource(from sourcePath: String,
                               havingEncoding encoding: String.Encoding? = nil,
                               to destinationPath: String) throws {
        self.verbosePrint("Generating source for '\(sourcePath)'")
        let s = try generateSource(from: sourcePath, havingEncoding: encoding)
        if FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.removeItem(atPath: destinationPath)
            } catch {
                verbosePrint("Unable to remove old version of '\(destinationPath)'")
            }
        }
        try s.source.write(toFile: destinationPath, atomically: false, encoding: s.encoding)
        if settings.lockGenFiles {
            do {
                //marking generated file as read-only
                try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 4444)], ofItemAtPath: destinationPath)
            } catch {
                verbosePrint("Unable to mark'\(destinationPath)' as readonly")
            }
        }
    }
    
    public func generateSource(from source: URL, havingEncoding encoding: String.Encoding? = nil, to destination: URL) throws {
        guard source.isFileURL else { throw Errors.mustBeFileURL(source) }
        guard destination.isFileURL else { throw Errors.mustBeFileURL(destination) }
        try generateSource(from: source.path, havingEncoding: encoding, to: destination.path)
    }
    
    public func generateSource(from source: URL) throws -> (String, String.Encoding) {
        guard source.isFileURL else { throw Errors.mustBeFileURL(source) }
        return try self.generateSource(from: source.path)
    }
}

extension StaticFileSourceCodeGenerator.StaticFile.FileType: Codable {
    enum Errors: Error, CustomStringConvertible {
        case invalidIANAEncodingType(String)
        case missingIANAEncodingType(String.Encoding)
        case unsupportedType(String)
        
        public var description: String {
            switch self {
            case .invalidIANAEncodingType(let str): return "Invalid IANA Encoding String '\(str)'"
            case .missingIANAEncodingType(let enc): return "Missing IANA Encoding String for '\(enc)'"
            case .unsupportedType(let str): return "Unsupported File Type '\(str)'.  Please make sure \(dSwiftModuleName) is up-to-date"
            }
        }
    }
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value.lowercased() {
            case "binary": self = .binary
            case "text": self = .text(.utf8)
            case _ where value.lowercased().hasPrefix("text(") && value.hasSuffix(")"):
                let startIdx = value.index(value.startIndex, offsetBy: 5)
                let endIdx = value.index(before: value.endIndex)
                let encString = String(value[startIdx..<endIdx])
                guard let enc = String.Encoding(IANACharSetName: encString) else {
                    throw Errors.invalidIANAEncodingType(encString)
                }
                self = .text(enc)
            default:
                throw Errors.unsupportedType(value)
        }
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .binary: try container.encode("binary")
        case .text(let enc):
            switch enc {
                case String.Encoding.utf8: try container.encode("text")
                default:
                    guard let iana = enc.IANACharSetName else {
                        throw Errors.missingIANAEncodingType(enc)
                    }
                    try container.encode("text(\(iana)")
            }
        }
    }
    
    
}
