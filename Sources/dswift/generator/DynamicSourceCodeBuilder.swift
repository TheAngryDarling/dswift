//
//  DynamicSourceCodeBuilder.swift
//  dswift
//
//  Created by Tyler Anger on 2018-12-05.
//

import Foundation
import VersionKit

class DynamicSourceCodeBuilder {
    
    enum Errors: Error, CustomStringConvertible {
        case missingClosingBlock(closing: String, for: String, in: String, onLine: Int)
        case missingOpeningBlock(for: String, in: String, onLine: Int)
        case invalidIncludedFileFormat(include: String, in: String, onLine: Int)
        case includedFileNotFound(include: String, includeFullPath: String, in: String, onLine: Int)
        case failedToIncludeFile(include: String, in: String, onLine: Int, error: Error)
        case foundUnprocessedInclude(include: String, in: String, onLine: Int)
        case invalidDSwiftToolsVersionNumber(for: String, ver: String)
        case minimumDSwiftToolsVersionNotMet(for: String, expected: String, found: String, description: String?)
        case missingBlockAttribute(block: String, attribute: String, in: String, onLine: Int)
        case blockAttributeMissingClosingQuote(block: String, attribute: String, in: String, onLine: Int)
        
        public var description: String {
            switch self {
            case .missingClosingBlock(closing: let closing, for: let opening, in: let path, onLine: let line):
                return "\(path): Missing closing '\(closing)' for '\(opening)' starting on line \(line)"
            case .missingOpeningBlock(for: let closing, in: let path, onLine: let line):
                return "\(path): Missing opening block for '\(closing)' finishing on line \(line)"
            case .invalidIncludedFileFormat(include: let include, let path, let line):
                return "\(path): Invalid Include File Format'\(include)' on line \(line)"
            case .includedFileNotFound(include: let include, includeFullPath: let includeFullPath, let path, let line):
                return "\(path): Include file '\(include)' / '\(includeFullPath)' on line \(line) not found"
            case .failedToIncludeFile(include: let include, let path, let line, let err):
                return "\(path): Failed to include '\(include)' on line \(line): \(err)"
            case .foundUnprocessedInclude(include: let include, let path, let line):
                return "\(path): Found unprocessed include '\(include)' on line \(line)"
            case .invalidDSwiftToolsVersionNumber(let path, let ver):
                return "\(path): Invalid dswift-tools-version '\(ver)'"
            case .minimumDSwiftToolsVersionNotMet(let path, let expected, let found, let desc):
                var rtn = "\(path): Minimum dswift-tools-version '\(expected)' not met.  Current version is '\(found)'"
                if let d = desc { rtn += ". " + d }
                return rtn
            case .missingBlockAttribute(let block, let attribute, let path, let line):
                return "Block tag '\(block)' missing attribute '\(attribute)' in file '\(path)' on line \(line)"
            case .blockAttributeMissingClosingQuote(let block, let attribute, let path, let line):
                return "Block tag '\(block)' missing attribute '\(attribute)'s ending quote in file '\(path)' on line \(line)"
                
            }
        }
    }
    
    enum CodeBlockDefinition {
        
        /// The opening brace of a code block
        var openingBrace: String {
            switch (self) {
                case .basic(let opening, _) : return opening
                case .static(let opening, _): return opening
                case .inline(let opening, _): return opening
                case .include(let opening, _): return opening
                case .text: return ""
            }
        }
        
        /// The closing brace of a code block
        var closingBrace: String {
            switch (self) {
                case .basic(_, let closing) : return closing
                case .static(_, let closing): return closing
                case .inline(_, let closing): return closing
                case .include(_, let closing): return closing
                case .text: return ""
            }
        }
        
        
        
        /// Indicator if the current code block is a basic block
        var isBasicBlock: Bool {
            if case .basic = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is a static block
        var isStaticBlock: Bool {
            if case .static(_, _) = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is an inline block
        var isInlineBlock: Bool {
            if case .inline = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is an include block
        var isIncludeBlock: Bool {
            if case .include(_, _) = self { return true }
            else { return false }
        }
        
        /// Indicator if the current code block is a text block
        var isTextBlock: Bool {
            if case .text = self { return true }
            else { return false }
        }
        
        case basic(opening: String, closing: String)
        case `static`(opening: String, closing: String)
        case inline(opening: String, closing: String)
        case include(opening: String, closing: String)
        case text
        
        init(basic: String, closing: String = "") {
            self = .basic(opening: basic, closing: closing)
        }
        init(`static`: String, closing: String = "") {
            self = .`static`(opening: `static`, closing: closing)
        }
        init(inline: String, closing: String = "") {
            self = .inline(opening: inline, closing: closing)
        }
        init(include: String, closing: String = "") {
            self = .include(opening: include, closing: closing)
        }
    }
    
    struct CodeBlockIdentifiers {
        
        struct CodeBlock {
            let range: Range<String.Index>
            let type: CodeBlockDefinition
            let string: String
            
            var lines: [String] { return CodeBlock.splitBlockString(self.string) }
            
            let subBlockString: String?
            var subBlockLines: [String]? {
                guard let l = self.subBlockString else { return nil }
                return CodeBlock.splitBlockString(l)
            }
            
            public init(range: Range<String.Index>, type: CodeBlockDefinition, string: String, subBlockString: String? = nil) {
                self.range = range
                self.type = type
                self.string = string
                self.subBlockString = subBlockString
            }
            
            private static func splitBlockString(_ string: String) -> [String] {
                return string.split(separator: "\n", omittingEmptySubsequences: false).map {
                    var rtn = String($0)
                    if String($0).hasSuffix("\r") {  rtn.removeLast() }
                    return rtn
                }
            }
        }
        
        let opening: String
        let closing: String
        
        let blocks: [CodeBlockDefinition]
        
        public var includeCodingBlock: CodeBlockDefinition? {
            return self.blocks.first(where: { return $0.isIncludeBlock })
        }
        
        var maxOpeningBlockSize: Int {
            var maxBlockSize: Int = 0
            for b in self.blocks {
                if b.openingBrace.count > maxBlockSize { maxBlockSize  = b.openingBrace.count }
            }
            return (self.opening.count + maxBlockSize)
        }
        var minOpeningBlockSize: Int {
            var minBlockSize: Int = self.blocks[0].openingBrace.count
            for b in self.blocks {
                if b.openingBrace.count < minBlockSize { minBlockSize  = b.openingBrace.count }
            }
            return (self.opening.count + minBlockSize)
        }
        
        var maxClosingBlockSize: Int {
            var maxBlockSize: Int = 0
            for b in self.blocks {
                if b.closingBrace.count > maxBlockSize { maxBlockSize  = b.closingBrace.count }
            }
            return (self.closing.count + maxBlockSize)
        }
        var minClosingBlockSize: Int {
            var minBlockSize: Int = self.blocks[0].closingBrace.count
            for b in self.blocks {
                if b.closingBrace.count < minBlockSize { minBlockSize  = b.closingBrace.count }
            }
            return (self.closing.count  + minBlockSize)
        }
        
        init(opening: String, closing: String, blocks: [CodeBlockDefinition]) {
            self.opening = opening
            self.closing = closing
            for b in blocks {
                if b.isTextBlock {
                    preconditionFailure("Do not provide CodeBlockDefinition.text in blocks array")
                }
            }
            //Make sure that the longest opening comes first
            self.blocks = blocks.sorted( by: { $0.openingBrace > $1.openingBrace } )
        }
        
        func nextBlockSet(from string: String, startingAt: String.Index, inFile file: String) throws -> CodeBlock? {
            //If we are at the end index, we are done
            guard startingAt !=  string.endIndex else { return nil }
            // Looks for opening block brace.  If not found we return the whole string as a text block
            let stBlockIndex: String.Index? = string.range(of: self.opening, range:startingAt..<string.endIndex)?.lowerBound
            
            if let closeBlockIndex: String.Index = string.range(of: self.closing, range:startingAt..<string.endIndex)?.lowerBound {
                if stBlockIndex == nil || closeBlockIndex < stBlockIndex! {
                    let line = string.countOccurrences(of: "\n",
                                                       inRange: string.startIndex..<closeBlockIndex)
                    throw Errors.missingOpeningBlock(for: self.closing, in: file, onLine: line + 1)
                }
            }
            
            guard let startBlockIndex = stBlockIndex else {
                return CodeBlock(range: startingAt..<string.endIndex,
                                 type: .text,
                                 string: String(string[startingAt..<string.endIndex]))
            }
            
            // Ensures that the opening of the block is at the starting index, otherwise we return a text block from startingAt to the beginning of the code block
            guard startBlockIndex == startingAt else {
                let str = String(string[startingAt..<startBlockIndex])
                return CodeBlock(range: startingAt..<startBlockIndex,
                                 type: .text,
                                 string: str)
            }
            
            let strMaxBlockIndicator: String.Index = string.index(startBlockIndex, offsetBy: self.maxOpeningBlockSize)
            let stringFrom: String = String(string[startBlockIndex..<strMaxBlockIndicator])
            
            for b in self.blocks {
                let op = self.opening + b.openingBrace
                if stringFrom.hasPrefix(op) {
                    let ed =  b.closingBrace + self.closing
                    guard let endBlockIndex: String.Index = string.range(of: ed, range:startBlockIndex..<string.endIndex)?.lowerBound else {
                        let line = string.countOccurrences(of: "\n",
                                                           inRange: string.startIndex..<startBlockIndex)
                        throw Errors.missingClosingBlock(closing: ed, for: op, in: file, onLine: line + 1)
                    }
                    
                    let innerOpening: String.Index = string.index(startBlockIndex, offsetBy: op.count)
                    var fullBlock: String = String(string[innerOpening..<endBlockIndex])
                    
                    if fullBlock.hasPrefix("\r") { fullBlock.removeFirst() }
                    if fullBlock.hasPrefix("\n") { fullBlock.removeFirst() }
                    
                    if fullBlock.hasSuffix("\n") {
                        fullBlock.removeLast()
                        if fullBlock.hasSuffix("\r") { fullBlock.removeLast() }
                    }
                    
                    
                    let outerEndBlockIndex: String.Index = string.index(endBlockIndex, offsetBy: ed.count)
                    
                    return CodeBlock(range: startBlockIndex..<outerEndBlockIndex,
                                     type: b,
                                     string: fullBlock)
                    
                    
                }
            }
            
            //Didn't get anywhere
            return nil
        }
        
        
    }
    
    public struct IncludedFile {
        let includeRange: Range<String.Index>
        let includePath: String
        let absoluePath: String
    }
    
    // The minimum dswift version to support '@include' coding block
    private static let minimumSupportedIncludeVersion: Version.SingleVersion = "1.0.18"
    //private static let includeCodingBlock = CodeBlockDefinition(include: "@include")
    
    private static let blockDefinitions: CodeBlockIdentifiers = CodeBlockIdentifiers(opening: "<%",
                                                                              closing: "%>",
                                                                              blocks: [CodeBlockDefinition(basic: ""),
                                                                                       CodeBlockDefinition(inline: "="),
                                                                                       CodeBlockDefinition(static: "!"),
                                                                                       CodeBlockDefinition(include: "@include")/*,
                                                                                 CodeBlockDefinition(variable: "@")*/])
    
    private var blockDefinitions: CodeBlockIdentifiers { return DynamicSourceCodeBuilder.blockDefinitions }
    
    
    private var source: String = ""
    private var file: String
    public private(set) var clsName: String
    public private(set) var sourceEncoding: String.Encoding
    private let dSwiftModuleName: String
    private let dSwiftURL: String
    
    public init(file: String, fileEncoding: String.Encoding? = nil, className: String, dSwiftModuleName: String, dSwiftURL: String) throws {
        self.file = file
        if let enc = fileEncoding {
            verbosePrint("Reading file '\(file.lastPathComponent)' with encoding \(enc)")
            self.source = try String(contentsOfFile: self.file, encoding: enc)
            self.sourceEncoding = enc
        } else {
             verbosePrint("Reading file '\(file.lastPathComponent)' with unknown encoding")
            var enc: String.Encoding = String.Encoding.utf8
            self.source = try String(contentsOfFile: self.file, foundEncoding: &enc)
            self.sourceEncoding = enc
        }
       
        self.clsName = className
        self.dSwiftModuleName = dSwiftModuleName
        self.dSwiftURL = dSwiftURL
        
        try DynamicSourceCodeBuilder.validateDSwiftToolsVersion(from: file.fullPath(),
                                                                source: self.source)
        
        
        // If we support Incldue blocks, we will automatically import them before processing any other blocks
        self.source = try DynamicSourceCodeBuilder.processIncludes(from: file.fullPath(),
                                                                   source: self.source)
        
    }
    
    
    
    public static func getDSwiftToolsVersion(from: String, source: String) throws -> Version.SingleVersion? {
        
        guard let r = source.range(of: "//(|\\s)dswift-tools-version:", options: .regularExpression),
           r.lowerBound == source.startIndex,
           let newLineRange = source.range(of: "\n", range: r.upperBound..<source.endIndex) else {
               return nil
           }
        // Copy text after : and before \n
        var line = String(source[r.upperBound..<newLineRange.lowerBound])
        // Remove white spaces
        line = line.trimmingCharacters(in: .whitespaces)
        
        guard let verNum = Version.SingleVersion(line) else {
            throw Errors.invalidDSwiftToolsVersionNumber(for: from, ver: line)
        }
        
        return verNum
        
    }
    
    private static func validateDSwiftToolsVersion(from: String,
                                                   source: String,
                                                   srcRequiredVersion: Version.SingleVersion) throws {
        
        let dswiftVer = Version.SingleVersion(dSwiftVersion)!
        
        guard dswiftVer >= srcRequiredVersion else {
            throw Errors.minimumDSwiftToolsVersionNotMet(for: from,
                                                            expected: srcRequiredVersion.description,
                                                            found: dSwiftVersion,
                                                            description: nil)
        }
    }
    
    
    private static func validateDSwiftToolsVersion(from: String,
                                                   source: String) throws {
        
        guard let requiedToolsVersion = try self.getDSwiftToolsVersion(from: from, source: source) else {
            // No version requirements, return from method
            return
        }
        
        try self.validateDSwiftToolsVersion(from: from,
                                            source: source,
                                            srcRequiredVersion: requiedToolsVersion)
    }
    
    public static func findIncludes(in path: String, source: String) throws -> [IncludedFile] {
        guard let includeBlock = self.blockDefinitions.blocks.first(where: { return $0.isIncludeBlock }) else {
            // include blocks not supported return empty array
            return []
        }
        let openingBlock = self.blockDefinitions.opening + includeBlock.openingBrace
        let closingBlock = includeBlock.closingBrace + self.blockDefinitions.closing
        
        var rtn: [IncludedFile] = []
        
        
        var includeStartLookingIndex = source.startIndex
        while let startIncludeRange = source.range(of: openingBlock,
                                               range: includeStartLookingIndex..<source.endIndex) {
            
            guard let endIncludeRange = source.range(of: closingBlock, range: startIncludeRange.upperBound..<source.endIndex) else {
                // Could not find end of block
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startIncludeRange.lowerBound)
                
                throw Errors.missingClosingBlock(closing: closingBlock,
                                                 for: openingBlock,
                                                 in: path,
                                                 onLine: line + 1)
            }
            
            guard let fromAttributeBeginRange = source.range(of: "\\s*file=\"", options: .regularExpression, range: startIncludeRange.upperBound..<endIncludeRange.lowerBound) else {
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startIncludeRange.lowerBound)
                
                throw Errors.missingBlockAttribute(block: openingBlock,
                                                  attribute: "file",
                                                  in: path,
                                                  onLine: line + 1)
            }
            
            guard let fromAttributeEndRange = source.range(of: "\"", range: fromAttributeBeginRange.upperBound..<endIncludeRange.lowerBound) else {
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startIncludeRange.lowerBound)
                throw Errors.blockAttributeMissingClosingQuote(block: openingBlock,
                                                              attribute: "file",
                                                              in: path,
                                                              onLine: line + 1)
            }
            
            var includeFile = String(source[fromAttributeBeginRange.upperBound..<fromAttributeEndRange.lowerBound])
            guard !includeFile.contains("\n") else {
                // Can not have new line characters
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startIncludeRange.lowerBound)
                throw Errors.invalidIncludedFileFormat(include: includeFile,
                                                       in: path,
                                                       onLine: line + 1)
            }
            
            verbosePrint("Found include '\(includeFile)' in '\(path)'")
            
            includeFile = includeFile.trimmingCharacters(in: .whitespaces)
            
            let includeFileFullPath = includeFile.fullPath(from: path.deletingLastPathComponent)
            
            guard FileManager.default.fileExists(atPath: includeFileFullPath) else {
                // Include file not found
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<startIncludeRange.lowerBound)
                throw Errors.includedFileNotFound(include: includeFile,
                                                  includeFullPath: includeFileFullPath,
                                                  in: path,
                                                  onLine: line + 1)
            }
            
            rtn.append(.init(includeRange: startIncludeRange.lowerBound..<endIncludeRange.upperBound,
                             includePath: includeFile,
                             absoluePath: includeFileFullPath))
            
            
            includeStartLookingIndex = endIncludeRange.upperBound
        }
        
        return rtn
    }
    
    public static func findIncludes(in path: String) throws -> [IncludedFile] {
        var enc: String.Encoding = String.Encoding.utf8
         let includeSrc = try String(contentsOfFile: path, usedEncoding: &enc)
        return try findIncludes(in: path, source: includeSrc)
    }
    
    private static func processIncludes(from: String,
                                        source: String) throws -> String {
        
        guard let srcMinToolsVer = try self.getDSwiftToolsVersion(from: from, source: source) else {
            return source
        }
        
        try self.validateDSwiftToolsVersion(from: from,
                                            source: source,
                                            srcRequiredVersion: srcMinToolsVer)
        
        guard  self.minimumSupportedIncludeVersion <= srcMinToolsVer else {
            throw Errors.minimumDSwiftToolsVersionNotMet(for: from,
                                                            expected: self.minimumSupportedIncludeVersion.description,
                                                            found: srcMinToolsVer.description,
                                                            description: "Tag @include requires a minimum version of '\(self.minimumSupportedIncludeVersion)'")
        }
        
        
        
        var includeBlock: [String: String] = [:]
        var includeSource: [String: String] = [:]
        
        let includes = try self.findIncludes(in: from, source: source)
        for include in includes {
            guard !includeSource.keys.contains(include.absoluePath) else {
                includeBlock[String(source[include.includeRange])] = include.absoluePath
                continue
            }
            do {
                verbosePrint("Reading include file '\(include.includePath)' / '\(include.absoluePath)' with unknown encoding")
               var enc: String.Encoding = String.Encoding.utf8
                let includeSrc = try String(contentsOfFile: include.absoluePath, usedEncoding: &enc)
                //verbosePrint("Read include file '\(includeFile)' with '\(enc)' encoding.")
                
                try DynamicSourceCodeBuilder.validateDSwiftToolsVersion(from: include.absoluePath,
                                                                        source: includeSrc)
                
                var processedIncludedSource: String = "// *** Begin Included '\(include.includePath)' ***\n"
                processedIncludedSource += try processIncludes(from: include.absoluePath,
                                                               source: includeSrc)
                processedIncludedSource += "\n// *** End Include '\(include.includePath)' ***\n"
                
                includeSource[include.absoluePath] = processedIncludedSource
                
                includeBlock[String(source[include.includeRange])] = include.absoluePath
               
            } catch {
                let line = source.countOccurrences(of: "\n",
                                                   inRange: source.startIndex..<include.includeRange.lowerBound)
                throw Errors.failedToIncludeFile(include: include.includePath,
                                                 in: from,
                                                 onLine: line + 1,
                                                 error: error)
            }
        }
        
        var rtn = source
        /// Replace all the includes with the real source
        for (includeBlock, sourceLocation) in includeBlock {
            rtn = rtn.replacingOccurrences(of: includeBlock, with: includeSource[sourceLocation]!)
        }
        
        return rtn
    }
    
    func strBlockToPrintCode(_ block: [String], tabs: Int) -> String {
        var rtn: String = ""
        
        let strTabs: String = "\t".repeated(tabs)
        
        for (index, line) in block.enumerated() {
            rtn += strTabs + "sourceBuilder += \"" + line.replacingOccurrences(of: "\\",
                                                                               with: "\\\\").replacingOccurrences(of: "\"",
                                                                                                                  with: "\\\"")
            if (index < block.count - 1) { rtn += "\\n" }
            rtn += "\""
            rtn += "\n"
        }
        
        
        return rtn
    }
    
    func generateSourceGenerator() throws -> String {
        var generatorContent: String = ""
        var classContent: String = ""
        var lastBlockEnding: String.Index = self.source.startIndex
        
         while let block = try blockDefinitions.nextBlockSet(from: self.source,
                                                             startingAt: lastBlockEnding,
                                                             inFile: self.file) {
             lastBlockEnding = block.range.upperBound
             // Changed from If Else statement to Switch to ensure each case gets processed
             // and compiler errors will occur if adding new block type case and forgetting to
             // add the processing of it here
             switch block.type {
                 case .text:
                     generatorContent += strBlockToPrintCode(block.lines, tabs: 2)
                 case .basic(opening: _, closing: _):
                     generatorContent += block.string + "\n"
                 case .inline(opening: _, closing: _):
                     generatorContent += "\t\tsourceBuilder += \"\\(" + block.string + ")\"\n"
                 case .static(opening: _, closing: _):
                     classContent += block.string + "\n"
                 case .include(opening: _, closing: _):
                    // Found include block when they should have been processed earlier
                    let line = source.countOccurrences(of: "\n",
                                                       inRange: source.startIndex..<block.range.lowerBound)
                 
                    throw Errors.foundUnprocessedInclude(include: block.string, in: self.file, onLine: line + 1)
                 
             }
             /*
             if block.type.isTextBlock { // Plain text
                 generatorContent += strBlockToPrintCode(block.lines, tabs: 2)
             } else if block.type.isBasicBlock { // ?%...%?
                 generatorContent += block.string + "\n"
             } else if block.type.isInlineBlock { // ?%=..%?
                 generatorContent += "\t\tsourceBuilder += \"\\(" + block.string + ")\"\n"
             } else if block.type.isStaticBlock {
                 classContent += block.string + "\n"
             }
             */
        }
        var completeSource: String = """
        import Foundation
        public class Out {
            public var buffer: String = ""
            public init() { }
        
            public func write(_ string: String) {
                self.buffer += string
            }
            public func println(_ string: String) {
                self.write(string + "\\n")
            }
        }
        
        public func +=(lhs: inout Out, rhs: String) {
            lhs.buffer += rhs
        }
        
        """
        
        completeSource += "public class \(clsName): NSObject {\n\n"
        
        completeSource += "\tpublic override var description: String { return generate() }\n\n"
        completeSource += classContent
        completeSource += "\n\tpublic func generate() -> String {\n"
        completeSource += "\t\tlet out = Out()\n\n"
        completeSource += "\t\tvar sourceBuilder = out\n\n"
        
        completeSource += "\t\tsourceBuilder += \"//  This file was dynamically generated from '\(self.file.lastPathComponent)' by \(dSwiftModuleName) v\(dSwiftVersion).  Please do not modify directly.\\n\"\n"
        completeSource += "\t\tsourceBuilder += \"//  \(dSwiftModuleName) can be found at \(dSwiftURL).\\n\\n\"\n"
        completeSource += generatorContent
        completeSource += "\n\t\treturn sourceBuilder.buffer\n"
        completeSource += "\t}\n"
        completeSource += "}\n"
        completeSource += "\n"
        completeSource += "if CommandLine.arguments.count != 2 {\n"
        completeSource += "\t print(\"Invalid parameters\")\n"
        completeSource += "} else {\n"
        completeSource += "\t let srcEncoding = String.Encoding(rawValue: \(self.sourceEncoding.rawValue))\n"
        completeSource += "\t let gen = \(clsName)()\n"
        completeSource += "\t let src = gen.generate()\n"
        completeSource += "\t try src.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), atomically: true, encoding: srcEncoding)\n"
        completeSource += "}"
        
        return completeSource
        
    }
}
