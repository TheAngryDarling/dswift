//
//  DSwiftSettings.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import BasicCodableHelpers
import SwiftPatches
import VersionKit

/// Settings structure for the config file
public struct DSwiftSettings {
    enum CodingKeys: String, CodingKey {
        case swiftPath
        case xcodeResourceSorting
        case license
        case readme
        case whenToAddBuildRules
        case generateXcodeProjectOnInit
        case regenerateXcodeProject
        case repository
        case authorName
        case authorContacts
        case lockGenFiels = "lockGeneratedFiles"
        case verboseMode
        case includeGeneratedFilesInXcodeProject
        case includeSwiftLintInXcodeProjectIfAvailable
        case includeSwiftLintInXcodeProject
        case autoInstallMissingPackages
        case defaultPackageInitToolsVersion
        case defaultGitIgnore
        case gitIgnoreAdditions
    }
    
    enum FileResourceSorting: String, Codable {
        case none
        case sorted
    }
    
    struct GenerateXcodeProjectOnInit {
        let types: [String: Bool]
        var isEmpty: Bool { return self.types.isEmpty }
        public init() { self.types = [:] }
        
        func canGenerated(forName name: String) -> Bool {
            if let val = self.types["all"] { return val }
            
            var name = name.lowercased()
            if name == "sysmod" { name = "system-module" }
            
            if let val = self.types[name] { return val }
            if let val = self.types["default"] { return val }
            
            return false
            
        }
        
        
    }
    
    /// Contact information for the developer
    enum Contact {
        case email(String)
        case address(String)
        case phone(String)
        case url(String)
        
        var isEmail: Bool {
            guard case Contact.email(_) = self else { return false }
            return true
        }
        var isAddress: Bool {
            guard case Contact.address(_) = self else { return false }
            return true
        }
        var isPhone: Bool {
            guard case Contact.phone(_) = self else { return false }
            return true
        }
        var isURL: Bool {
            guard case Contact.url(_) = self else { return false }
            return true
        }
        
        internal var string: String {
            switch self {
                case .email(let string): return string
                case .address(let string): return string
                case .phone(let string): return string
                case .url(let string): return string
            }
        }
    }
    
    /// The difference supported license types
    enum License {
        case none
        case file(URL)
        case apache2_0
        case gnuGPL3_0
        case gnuAGPL3_0
        case gnuLGPL3_0
        case mozilla2_0
        case mit
        case unlicense
        
        public var isNone: Bool {
            guard case .none = self else { return false }
            return true
        }
        
        /// Returns the display name of the license, otherwise an empty string if no display name is available
        var displayName: String {
            switch self {
                case .apache2_0: return "Apache License v2.0"
                case .gnuGPL3_0: return "GNU General Public License v3.0"
                case .gnuAGPL3_0: return "GNU Affero General Public License v3.0"
                case .gnuLGPL3_0: return "GNU Lesser General Public License v3.0"
                case .mozilla2_0: return "Mozilla Public License 2.0"
                case .mit: return "MIT"
                case .unlicense: return "The Unlicense"
                default: return ""
            }
        }
        // Name of the ReadME badge or empty string if there isn't one
        var badgeName: String {
            switch self {
                case .apache2_0: return "Apache 2.0"
                case .gnuGPL3_0: return "GPL v3"
                case .gnuAGPL3_0: return "AGPL v3"
                case .gnuLGPL3_0: return "LGPL v3"
                case .mozilla2_0: return "MPL 2.0"
                case .mit: return "MIT"
                case .unlicense: return "Unlicense"
                default: return ""
            }
        }
        // Colour of the ReadME badge or empty string if there isn't one
        var badgeColour: String {
            switch self {
                case .apache2_0: return "blue"
                case .gnuGPL3_0: return "blue"
                case .gnuAGPL3_0: return "blue"
                case .gnuLGPL3_0: return "blue"
                case .mozilla2_0: return "brightgreen"
                case .mit: return "yellow"
                case .unlicense: return "blue"
                default: return ""
            }
        }
        
        var readmeText: String {
            switch self {
                case .apache2_0: return Licenses.apache2_0_README()
                case .gnuGPL3_0: return Licenses.gnuGPL3_0_README()
                case .gnuAGPL3_0: return Licenses.gnuAGPL3_0_README()
                case .gnuLGPL3_0: return Licenses.gnuLGPL3_0_README()
                case .mozilla2_0: return Licenses.mozilla2_0_README()
                case .mit: return Licenses.mit_README()
                case .unlicense: return Licenses.unlicense_README()
                default: return Licenses.defaultLicenseReadMe()
            }
        }
        
    }
    
    /// Developer repository information
    struct Repository {
        
        enum CodingKeys: String, CodingKey {
            case serviceName
            case serviceURL
            case repositoryName
        }
        /// Repository Service Name (eg GitHub, GitLab, etc...)
        let serviceName: String?
        /// URL to the developer repository
        let serviceURL: URL
        /// Repository name (eg last part of service url)
        let repositoryName: String?
        /// description build for ReadME file
        var readMEDescription: String {
            var rtn: String = "["
            if let s = serviceName { rtn += s }
            if let r = repositoryName {
                if rtn != "[" { rtn += " - " }
                rtn += r
            }
            if rtn == "[" { rtn += serviceURL.lastPathComponent }
            rtn += "](\(serviceURL.absoluteString))"
            return rtn
        }
    }
    
    /// Difference location of readme files
    struct ReadMe {
        /// Readme Type, Either URL or auto-generated
        public enum ReadMeType {
            case url(URL)
            case generated
            
            var url: URL? {
                guard case .url(let val) = self else { return nil }
                return val
            }
        }
        
        let types: [String: ReadMeType]
        var isEmpty: Bool { return self.types.isEmpty }
        public init() { self.types = [:] }
        
        func getType(forName name: String) -> ReadMeType? {
            if let val = self.types["all"] { return val }
            
            var name = name.lowercased()
            if name == "sysmod" { name = "system-module" }
            
            if let val = self.types[name] { return val }
            if let val = self.types["default"] { return val }
            
            return nil
            
        }
    }
    
    enum AddingBuildRulesRule: String, Codable {
        case always
        case whenNeeded
        
        func canAddBuildRules(_ project: URL) throws -> Bool {
            switch self {
                case .always: return true
                case .whenNeeded: return try generator.containsSupportedFiles(inFolder: project)
            }
        }
    }
    
    enum Useability: String, Codable {
        case always
        case whenAvailable
        case never
    }
    
    /// The default swift path
    public static let defaultSwiftPath: String = "/usr/bin/swift"
    /// The path to the swift to use (Default: DSwiftSettings.defaultSwiftPath)
    var swiftPath: String
    /// Indictor if the Xcode Project structure should be sorted or not
    let xcodeResourceSorting: FileResourceSorting
    /// License settings
    let license: License
    /// Readme settings
    let readme: ReadMe
    /// Indicator of when to add build rules
    let whenToAddBuildRules: AddingBuildRulesRule
    /// Indicator if 'swift packgae generate-xcodeproj' should be executed after 'swift package init'
    let generateXcodeProjectOnInit: GenerateXcodeProjectOnInit
    /// Indicator if 'swift packgae generate-xcodeproj' should be executed after any 'swift package update'
    let regenerateXcodeProject: Bool
    /// Developer repository information
    let repository: Repository?
    /// Author Name for use in README.md file when generated
    let authorName: String?
    /// Author Contact for use in README.md file when generated
    //let authorContacts: [Contact]
    /// Lock generated files.  Locks any generated files from being modified
    let lockGenFiles: Bool
    /// Indicator if we should be in verbose mode
    let verboseMode: Bool
    /// Indicator if we should be in verbose mode (checks env variable dswiftVerbose and then checks verboseMode property)
    var isVerbose: Bool {
        guard let envVar = ProcessInfo.processInfo.environment["dswiftVerbose"] else {
            return self.verboseMode
        }
        return (envVar.lowercased() == "true")
    }
    /// Indicator if generated source code files should be included in Xcode Projects
    let includeGeneratedFilesInXcodeProject: Bool
    /// indicator, if when generating Xcode Project file would install SwifLint Build Phase Script
    let includeSwiftLintInXcodeProject: Useability
    
    /// Indicator if we should try to auto install any missing system packages from the package manager
    /// when requirements are found within the project, otherwise we will just give a warning
    let autoInstallMissingPackages: Bool
    /// Set the package tools version to the give value when creating new package if the value is set
    let defaultPackageInitToolsVersion: String?
    /// Allows for the settings file to override the default gitignore file
    let defaultGitIgnore: GitIgnoreFile?
    /// Allows for the settings file to add additional rules to the gitignore file
    let gitIgnoreAdditions: GitIgnoreFile?
    
    public init() {
        self.swiftPath = DSwiftSettings.defaultSwiftPath
        self.xcodeResourceSorting = .none
        self.license = .none
        self.readme = ReadMe()
        self.whenToAddBuildRules = .always
        self.generateXcodeProjectOnInit = GenerateXcodeProjectOnInit()
        self.regenerateXcodeProject = false
        self.repository = nil
        self.authorName = nil
        //self.authorContacts = []
        self.lockGenFiles = true
        self.verboseMode = false
        self.includeGeneratedFilesInXcodeProject = false
        self.includeSwiftLintInXcodeProject = .never
        self.autoInstallMissingPackages = false
        self.defaultPackageInitToolsVersion = nil
        self.defaultGitIgnore = nil
        self.gitIgnoreAdditions = nil
    }
}

extension DSwiftSettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        #if NO_DSWIFT_PARAMS
        self.swiftPath = DSwiftSettings.defaultSwiftPath
        #else
        self.swiftPath = try container.decodeIfPresent(String.self,
                                                       forKey: .swiftPath,
                                                       withDefaultValue: DSwiftSettings.defaultSwiftPath)
        #endif
        self.xcodeResourceSorting = try container.decodeIfPresent(FileResourceSorting.self,
                                                                  forKey: .xcodeResourceSorting,
                                                                  withDefaultValue: .none)
        self.license = try container.decodeIfPresent(License.self,
                                                     forKey: .license,
                                                     withDefaultValue: .none)
        self.readme = try container.decodeIfPresent(ReadMe.self,
                                                    forKey: .readme,
                                                    withDefaultValue: ReadMe())
        self.whenToAddBuildRules = try container.decodeIfPresent(AddingBuildRulesRule.self,
                                                                 forKey: .whenToAddBuildRules,
                                                                 withDefaultValue: .always)
        self.generateXcodeProjectOnInit = try container.decodeIfPresent(GenerateXcodeProjectOnInit.self,
                                                                        forKey: .generateXcodeProjectOnInit,
                                                                        withDefaultValue: GenerateXcodeProjectOnInit())
        self.regenerateXcodeProject = try container.decodeIfPresent(Bool.self,
                                                                    forKey: .regenerateXcodeProject,
                                                                    withDefaultValue: false)
        self.repository = try container.decodeIfPresent(Repository.self,
                                                        forKey: .repository)
        self.authorName = try container.decodeIfPresent(String.self,
                                                        forKey: .authorName)
        //self.authorContacts = try container.decodeFromSingleOrArrayIfPresentWithEmptyDefault(Contact.self, forKey: .authorContacts)
        self.lockGenFiles = try container.decodeIfPresent(Bool.self,
                                                          forKey: .lockGenFiels,
                                                          withDefaultValue: true)
        self.verboseMode = try container.decodeIfPresent(Bool.self,
                                                         forKey: .verboseMode,
                                                         withDefaultValue: false)
        self.includeGeneratedFilesInXcodeProject = try container.decodeIfPresent(Bool.self,
                                                                                 forKey: .includeGeneratedFilesInXcodeProject,
                                                                                 withDefaultValue: false)
        var swiftLint: Useability = .never
        if let useSwiftLint = try container.decodeIfPresent(Useability.self, forKey: .includeSwiftLintInXcodeProject) {
            swiftLint = useSwiftLint
        } else if let useSwiftLint = try container.decodeIfPresent(Bool.self, forKey: .includeSwiftLintInXcodeProjectIfAvailable), useSwiftLint {
            swiftLint = .whenAvailable
        }
        
        self.includeSwiftLintInXcodeProject = swiftLint
        
        #if AUTO_INSTALL_PACKAGES
        self.autoInstallMissingPackages = true
        #else
        self.autoInstallMissingPackages = try container.decodeIfPresent(Bool.self,
                                                                        forKey: .autoInstallMissingPackages,
                                                                        withDefaultValue: false)
        #endif
        
        self.defaultPackageInitToolsVersion = try container.decodeIfPresent(String.self,
                                                                            forKey: .defaultPackageInitToolsVersion)
        
        self.defaultGitIgnore = try container.decodeIfPresent(GitIgnoreFile.self,
                                                              forKey: .defaultGitIgnore)
        self.gitIgnoreAdditions = try container.decodeIfPresent(GitIgnoreFile.self,
                                                                forKey: .gitIgnoreAdditions)
        
    }

    public init(from url: URL) throws {
        let jsonDecoder = JSONDecoder()
        //let dta = try Data(contentsOf: url.standardizedFileURL.resolvingSymlinksInPath())
        //var encoding: String.Encoding = .utf8
        //var str: String = try String(contentsOf: url.standardizedFileURL.resolvingSymlinksInPath(), usedEncoding: &encoding)
        var encoding: String.Encoding = .utf8
        var str: String = try String(contentsOf: url.standardizedFileURL.resolvingSymlinksInPath(), foundEncoding: &encoding)
        
        
        let commentTypes: [String] = ["//", "#"]
        for comment in commentTypes {
            var lines = str.split(separator: "\n").map(String.init)
            var i: Int = 0
            while i < lines.count {
                if lines[i].ltrim().hasPrefix(comment) {
                    lines.remove(at: i)
                } else {
                    i += 1
                }
            }
            
            str = lines.joined(separator: "\n")
            
            
        }
        //print(str)
        // Remove empty lines
        str = str.split(separator: "\n").joined(separator: "\n")
        do {
            self = try jsonDecoder.decode(DSwiftSettings.self, from: str.data(using: encoding)!)
        } catch {
            errPrint(str)
            throw error
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.swiftPath, forKey: .swiftPath)
        try container.encode(self.xcodeResourceSorting, forKey: .xcodeResourceSorting)
        try container.encode(self.license, forKey: .license )
        if !self.readme.isEmpty { try container.encode(self.readme, forKey: .readme) }
        try container.encode(self.whenToAddBuildRules, forKey: .whenToAddBuildRules, ifNot: .always)
        try container.encode(self.generateXcodeProjectOnInit, forKey: .generateXcodeProjectOnInit)
        try container.encode(self.regenerateXcodeProject, forKey: .regenerateXcodeProject )
        try container.encodeIfPresent(self.repository, forKey: .repository)
        try container.encodeIfPresent(self.authorName, forKey: .authorName)
        //try container.encodeToSingleOrArray(self.authorContacts, forKey: .authorContacts)
        try container.encode(self.verboseMode, forKey: .verboseMode, ifNot: false)
        try container.encode(self.includeGeneratedFilesInXcodeProject, forKey: .includeGeneratedFilesInXcodeProject, ifNot: false)
        try container.encode(self.includeSwiftLintInXcodeProject, forKey: .includeSwiftLintInXcodeProject, ifNot: .never)
        try container.encode(self.autoInstallMissingPackages, forKey: .autoInstallMissingPackages, ifNot: false)
        try container.encodeIfPresent(self.defaultPackageInitToolsVersion, forKey: .defaultPackageInitToolsVersion)
        try container.encodeIfPresent(self.defaultGitIgnore, forKey: .defaultGitIgnore)
        try container.encodeIfPresent(self.gitIgnoreAdditions, forKey: .gitIgnoreAdditions)
    }
}
extension DSwiftSettings.GenerateXcodeProjectOnInit: Codable {
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            let val = try container.decode(Bool.self)
            self.types = ["all": val]
        } else {
            var tps: [String: Bool] = [:]
            let container = try decoder.container(keyedBy: CodableKey.self)
            for key in container.allKeys {
                let v = try container.decode(Bool.self, forKey: key)
                var strKey = key.stringValue.lowercased()
                if strKey == "sysmod" { strKey = "system-module" }
                tps[strKey] = v
            }
            self.types = tps
        }
    }
    public func encode(to encoder: Encoder) throws {
        
        if let v = self.types["all"], self.types.count == 1 {
            var container = encoder.singleValueContainer()
            try container.encode(v)
        } else {
            var container = encoder.container(keyedBy: CodableKey.self)
            for (strKey, v) in self.types {
                try container.encode(v, forKey: CodableKey(stringValue: strKey.lowercased()))
            }
        }
        guard !self.isEmpty else { return }
    }
}
extension DSwiftSettings.License: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        switch str {
            case "none": self = .none
            case "apache2_0": self = .apache2_0
            case "gnuGPL3_0": self = .gnuGPL3_0
            case "gnuAGPL3_0": self = .gnuAGPL3_0
            case "gnuLGPL3_0": self = .gnuLGPL3_0
            case "mozilla2_0": self = .mozilla2_0
            case "mit": self = .mit
            case "unlicense": self = .unlicense
            default:
                if str.hasPrefix("/") || str.hasPrefix(".") || str.hasPrefix("~") {
                    self = .file(URL(fileURLWithPath: NSString(string: str).expandingTildeInPath))
                } else {
                    if let url = URL(string: str) {
                        self = .file(url)
                    } else {
                        print("Invalid license url '\(str)'.")
                        self = .none
                    }
                    
                }
        }
    }
    public func encode(to encoder: Encoder) throws {
        guard !self.isNone else { return }
        var container = encoder.singleValueContainer()
        switch self {
            case .none: try container.encode("none")
            case .apache2_0: try container.encode("apache2.0")
            case .gnuGPL3_0: try container.encode("gnuGPL3.0")
            case .gnuAGPL3_0: try container.encode("gnuAGPL3.0")
            case .gnuLGPL3_0: try container.encode("gnuLGPL3.0")
            case .mozilla2_0: try container.encode("mozilla2_0")
            case .mit: try container.encode("mit")
            case .unlicense: try container.encode("unlicense")
            case .file(let url): try container.encode(url)
        }
    }
    
    /// Write license to given location
    public func write(to url: URL) throws {
        switch self {
            case .file(let licenseURL):
                print("Creating License.md")
                if licenseURL.isFileURL {
                    let path = licenseURL.path
                    let lURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                    try FileManager.default.copyItem(at: lURL, to: url)
                } else {
                    //var enc: String.Encoding = .utf8
                    //let str = try String(contentsOf: licenseURL, usedEncoding: &enc)
                    //try str.write(to: url, atomically: true, encoding: enc)
                    let dta = try Data(contentsOf: licenseURL)
                    try dta.write(to: url, options: .atomic)
                }
            case .apache2_0:
                print("Creating License.md")
                try Licenses.apache2_0().write(to: url, atomically: true, encoding: .utf8)
            case .gnuGPL3_0:
                print("Creating License.md")
                try Licenses.gnuGPL3_0().write(to: url, atomically: true, encoding: .utf8)
            case .gnuAGPL3_0:
                print("Creating License.md")
                try Licenses.gnuAGPL3_0().write(to: url, atomically: true, encoding: .utf8)
            case .gnuLGPL3_0:
                print("Creating License.md")
                try Licenses.gnuLGPL3_0().write(to: url, atomically: true, encoding: .utf8)
            case .mozilla2_0:
                print("Creating License.md")
                try Licenses.mozilla2_0().write(to: url, atomically: true, encoding: .utf8)
            case .mit:
                print("Creating License.md")
                try Licenses.mit().write(to: url, atomically: true, encoding: .utf8)
            case .unlicense:
                print("Creating License.md")
                try Licenses.unlicense().write(to: url, atomically: true, encoding: .utf8)
            default: break
        }
    }
}

extension DSwiftSettings.Contact: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let address = try? container.decode([String].self) {
            self = .address(address.joined(separator: "\n"))
        } else {
            let str = try container.decode(String.self)
            if str.hasPrefix("mailto:") {
                self = .email(String(str.suffix(from: str.index(str.startIndex, offsetBy: "mailto:".count))))
            } else if str.hasPrefix("tel:") {
                self = .phone(String(str.suffix(from: str.index(str.startIndex, offsetBy: "tel:".count))))
            } else {
                self = .url(str)
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if self.isEmail { try container.encode("mailto:" + self.string) }
        else if self.isPhone { try container.encode("tel:" + self.string) }
        else if self.isAddress { try container.encode(self.string.split(separator: "\n").map(String.init)) }
        else { try container.encode(self.string) }
    }
}
extension DSwiftSettings.Repository: Codable {
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            self.serviceName = nil
            self.serviceURL = try container.decode(URL.self)
            self.repositoryName = self.serviceURL.lastPathComponent
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName)
            self.serviceURL = try container.decode(URL.self, forKey: .serviceURL)
            self.repositoryName = try container.decodeIfPresent(String.self, forKey: .repositoryName)
        }
    }
    public func encode(to encoder: Encoder) throws {
        if (self.repositoryName == nil && self.serviceName == nil) ||
            ( self.serviceName == nil && self.repositoryName == self.serviceURL.lastPathComponent) {
            var container = encoder.singleValueContainer()
            try container.encode(self.serviceURL)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.serviceName, forKey: .serviceName)
            try container.encode(self.serviceURL, forKey: .serviceURL)
            try container.encodeIfPresent(self.repositoryName, forKey: .repositoryName)
        }
    }
}

extension DSwiftSettings.ReadMe.ReadMeType: Codable {
    public enum Errors: Error {
        case invalidURL(String)
    }
    private static func decodeURL(_ string: String) -> URL? {
        if string.hasPrefix("/") || string.hasPrefix(".") || string.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: string).expandingTildeInPath)
        } else { return URL(string: string) }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        if str == "generated" { self = .generated }
        else if let url = DSwiftSettings.ReadMe.ReadMeType.decodeURL(str) {
            self = .url(url)
        } else {
            throw Errors.invalidURL(str)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .generated: try container.encode("generated")
            case .url(let url): try container.encode(url)
        }
    }
}

extension DSwiftSettings.ReadMe.ReadMeType: Equatable {
    static func == (lhs: DSwiftSettings.ReadMe.ReadMeType, rhs: DSwiftSettings.ReadMe.ReadMeType) -> Bool {
        switch (lhs, rhs) {
            case (.generated, .generated): return true
            case (.url(let lhsURL), .url(let rhsURL)): return lhsURL == rhsURL
            default: return false
        }
    }
}

extension DSwiftSettings.ReadMe: Codable {
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            let val = try container.decode(DSwiftSettings.ReadMe.ReadMeType.self)
            self.types = ["all": val]
        } else {
            let container = try decoder.container(keyedBy: CodableKey.self)
            var tps: [String: ReadMeType] = [:]
            for key in container.allKeys {
                var strKey = key.stringValue.lowercased()
                if strKey == "sysmod" { strKey = "system-module" }
                let val = try container.decode(DSwiftSettings.ReadMe.ReadMeType.self, forKey: key)
                tps[strKey] = val
            }
            self.types = tps
        }
    }
    
    
    public func encode(to encoder: Encoder) throws {
        if let allVal = self.types["all"] {
            var container = encoder.singleValueContainer()
            try container.encode(allVal)
        } else {
            var container = encoder.container(keyedBy: CodableKey.self)
            for (strKey, val) in self.types {
                try container.encode(val, forKey: CodableKey(stringValue: strKey.lowercased()))
            }
        }
    }
    
    
    /// Write readme file to specific location
    public func write(to url: URL, for modType: String, withName name: String, includeDSwiftMessage dswiftMessage: Bool = true) throws {
        
        //guard let readmeType = readme else { return }
        guard let readmeType = self.getType(forName: modType) else { return }
        
        if var rURL = readmeType.url {
            print("Replacing README.md with \(rURL)")
            if rURL.isFileURL {
                let path = rURL.path
                rURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
                guard FileManager.default.fileExists(atPath: path) else  {
                    errPrint("Missing ReadMe File'\(path)'")
                    return
                }
                try FileManager.default.copyItem(at: rURL, to: url)
            } else {
                //var enc: String.Encoding = .utf8
                //let str = try String(contentsOf: rURL, usedEncoding: &enc)
                //try str.write(to: url, atomically: true, encoding: enc)
                let dta = try Data(contentsOf: rURL)
                try dta.write(to: url, options: .atomic)
            }
            
            var readMe = try StringFile(url.path)
            
            if let author = settings.authorName, !author.isEmpty {
                readMe.replaceOccurrences(of: "{author_name}", with: author)
            }
            
            if let r = settings.repository {
                if let rName = r.repositoryName {
                    readMe.replaceOccurrences(of: "{repository_name}", with: rName)
                }
                if let sName = r.serviceName {
                    readMe.replaceOccurrences(of: "{repository_service}", with: sName)
                }
                readMe.replaceOccurrences(of: "{repository_url}", with: r.serviceURL.absoluteString)
            }
            
            try readMe.save()
            
        } else {
            print("Replacing README.md with generated file")
            var readmeContents: String = "# \(name)\n\n"
            var packageVersion: String = "4.0"
            let packageFileURL = currentProjectURL.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageFileURL.path) {
                do {
                    let src = try String(contentsOf: packageFileURL)
                    let firstLine = String(src.split(separator: "\n").first!)
                    packageVersion = firstLine.replacingOccurrences(of: "// swift-tools-version:", with: "")
                    readmeContents += "![swift >= \(packageVersion)](https://img.shields.io/badge/swift-%3E%3D\(packageVersion)-brightgreen.svg)\n"
                } catch {}
            }
            readmeContents += "![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)\n"
            readmeContents += "![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)\n"
            if !settings.license.isNone && !settings.license.badgeName.isEmpty {
                
                let webEscapedName = settings.license.badgeName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let licenseBadgeStr = "![\(settings.license.badgeName)](https://img.shields.io/badge/License-\(webEscapedName)-\(settings.license.badgeColour).svg?style=flat)"
                readmeContents += "[\(licenseBadgeStr)](LICENSE.md)\n"
            }
            readmeContents += "\n"
            readmeContents += "<Project description goes here>\n\n"
            
            readmeContents += "## Requirements\n\n"
            if let v = Version.SingleVersion(packageVersion) {
                let req = XcodeProjectBuilders.DefaultDetailsChoice.swiftVersion(v)
                if let buildOptions = req.mostCompatible() {
                    readmeContents += "* \(buildOptions.compatibleXcode)+ (If working within Xcode)\n"
                    if let sV = buildOptions.swiftVersion {
                        readmeContents += "* \(sV)+\n"
                    }
                    readmeContents += "\n"
                }
            }
            
            if dswiftMessage {
                readmeContents += "> Note: This package used [\(dSwiftModuleName)](\(dSwiftURL)) to generate some, or all, of its source code.  While the generated source code should be included and available in this package so building directly with swift is possible, if missing, you may need to download and build with [\(dSwiftModuleName)](\(dSwiftURL))\n\n"
            }
            
            readmeContents += "## Usage\n\n"
            readmeContents += "<Usage goes here>\n\n"
            readmeContents += "```swift\n\n"
            readmeContents += "```\n\n"
            readmeContents += "## Dependencies\n\n"
            readmeContents += "<Project dependencies goes here or remove this section>\n\n"
            readmeContents += "## Author\n\n"
            readmeContents += "* **\(settings.authorName ?? XcodeProjectBuilders.UserDetails().displayName!)** - *Initial work* "
            if let r = settings.repository {
                readmeContents += " - " + r.readMEDescription
            }
            readmeContents += "\n\n"
            
            if !settings.license.isNone {
                readmeContents += "## License\n\n"
                readmeContents += settings.license.readmeText + "\n\n"
                //readmeContents += "This project is licensed under \(settings.license.displayName) - see the [LICENSE.md](LICENSE.md) file for details.\n\n"
            }
            readmeContents += "## Acknowledgments\n\n"
            readmeContents += "<Acknowledgments goes here or remove this section>"
            
            try readmeContents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
