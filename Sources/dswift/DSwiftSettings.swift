//
//  DSwiftSettings.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj

/// Settings structure for the config file
struct DSwiftSettings {
    enum CodingKeys: String, CodingKey {
        case swiftPath
        case xcodeResourceSorting
        case license
        case readme
        case regenerateXcodeProject
        case repository
    }
    
    enum FileResourceSorting: String, Codable {
        case none
        case sorted
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
        enum CodingKeys: String, CodingKey {
            case library
            case executable
            case sysMod
        }
        /// Readme Type, Either URL or auto-generated
        public enum ReadMeType {
            case url(URL)
            case generated
            
            var url: URL? {
                guard case .url(let val) = self else { return nil }
                return val
            }
        }
        /// ReadME type for library projects
        let library: ReadMeType?
        /// ReadME type for executable projects
        let executable: ReadMeType?
        /// ReadME type for Sys-Mod projects
        let sysMod: ReadMeType?
        /// Are all project types nil
        var isEmpty: Bool {
            return  (self.executable == nil &&
                     self.library == nil &&
                     self.sysMod == nil)
        }
        
        public init() {
            self.library = nil
            self.executable = nil
            self.sysMod = nil
        }
        
    }
    
    fileprivate static let defaultSwiftPath: String = "/usr/bin/swift"
    /// The path to the swift to use (Default: /usr/bin/swift)
    var swiftPath: String
    /// Indictor if the Xcode Project structure should be sorted or not
    let xcodeResourceSorting: FileResourceSorting
    /// License settings
    let license: License
    /// Readme settings
    let readme: ReadMe
    /// Indicator if 'swift packgae generate-xcodeproj' should be executed after any 'swift package update'
    let regenerateXcodeProject: Bool
    /// Developer repository information
    let repository: Repository?
    
    public init() {
        self.swiftPath = DSwiftSettings.defaultSwiftPath
        self.xcodeResourceSorting = .none
        self.license = .none
        self.readme = ReadMe()
        self.regenerateXcodeProject = false
        self.repository = nil
    }
}

extension DSwiftSettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.swiftPath = try container.decodeIfPresent(String.self, forKey: .swiftPath) ?? DSwiftSettings.defaultSwiftPath
        self.xcodeResourceSorting = try container.decodeIfPresent(FileResourceSorting.self, forKey: .xcodeResourceSorting) ?? FileResourceSorting.none
        self.license = try container.decodeIfPresent(License.self, forKey: .license) ?? .none
        self.readme = try container.decodeIfPresent(ReadMe.self, forKey: .readme) ?? ReadMe()
        self.regenerateXcodeProject = try container.decodeIfPresent(Bool.self, forKey: .regenerateXcodeProject) ?? false
        self.repository = try container.decodeIfPresent(Repository.self, forKey: .repository)
        
    }
    
    public init(from url: URL) throws {
        let jsonDecoder = JSONDecoder()
        //let dta = try Data(contentsOf: url.standardizedFileURL.resolvingSymlinksInPath())
        var encoding: String.Encoding = .utf8
        var str: String = try String(contentsOf: url.standardizedFileURL.resolvingSymlinksInPath(), usedEncoding: &encoding)
        
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
        try container.encode(self.regenerateXcodeProject, forKey: .regenerateXcodeProject )
        try container.encodeIfPresent(self.repository, forKey: .repository)
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
                    var enc: String.Encoding = .utf8
                    let str = try String(contentsOf: licenseURL, usedEncoding: &enc)
                    try str.write(to: url, atomically: true, encoding: enc)
                }
            case .apache2_0:
                print("Creating License.md")
                try Licenses.apache2_0.write(to: url, atomically: true, encoding: .utf8)
            case .gnuGPL3_0:
                print("Creating License.md")
                try Licenses.gnuGPL3_0.write(to: url, atomically: true, encoding: .utf8)
            case .gnuAGPL3_0:
                print("Creating License.md")
                try Licenses.gnuAGPL3_0.write(to: url, atomically: true, encoding: .utf8)
            case .gnuLGPL3_0:
                print("Creating License.md")
                try Licenses.gnuLGPL3_0.write(to: url, atomically: true, encoding: .utf8)
            case .mozilla2_0:
                print("Creating License.md")
                try Licenses.mozilla2_0.write(to: url, atomically: true, encoding: .utf8)
            case .mit:
                print("Creating License.md")
                try Licenses.mit.write(to: url, atomically: true, encoding: .utf8)
            case .unlicense:
                print("Creating License.md")
                try Licenses.unlicense.write(to: url, atomically: true, encoding: .utf8)
            default: break
        }
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
            self.executable = val
            self.library = val
            self.sysMod = val
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.executable = try container.decodeIfPresent(DSwiftSettings.ReadMe.ReadMeType.self, forKey: .executable)
            self.library = try container.decodeIfPresent(DSwiftSettings.ReadMe.ReadMeType.self, forKey: .library)
            self.sysMod = try container.decodeIfPresent(DSwiftSettings.ReadMe.ReadMeType.self, forKey: .sysMod)
        }
    }
    
    
    public func encode(to encoder: Encoder) throws {
        if self.executable != nil &&
           self.executable == self.library &&
           self.executable == self.sysMod {
            var container = encoder.singleValueContainer()
            try container.encode(self.executable!)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(self.executable, forKey: .executable)
            try container.encodeIfPresent(self.library, forKey: .library)
            try container.encodeIfPresent(self.sysMod, forKey: .sysMod)
        }
    }
    
    /// Write readme file to specific location
    public func write(to url: URL, for modType: String, withName name: String) throws {
        var readme: DSwiftSettings.ReadMe.ReadMeType? = nil
        switch modType.lowercased() {
            case "library": readme = self.library
            case "executable": readme = self.executable
            case "system-module": readme = self.sysMod
            default: break
        }
        
        guard let readmeType = readme else { return }
        
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
                var enc: String.Encoding = .utf8
                let str = try String(contentsOf: rURL, usedEncoding: &enc)
                try str.write(to: url, atomically: true, encoding: enc)
            }
        } else {
            print("Replacing README.md with generated file")
            var readmeContents: String = "# \(name)\n\n"
            let packageFileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageFileURL.path) {
                do {
                    let src = try String(contentsOf: packageFileURL)
                    let firstLine = String(src.split(separator: "\n").first!)
                    let version = firstLine.replacingOccurrences(of: "// swift-tools-version:", with: "")
                    readmeContents += "![swift >= \(version)](https://img.shields.io/badge/swift-%3E%3D\(version)-brightgreen.svg)\n"
                } catch {}
            }
            readmeContents += "![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)\n"
            readmeContents += "![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)\n"
            if !settings.license.isNone && !settings.license.badgeName.isEmpty {
                
                let webEscapedName = settings.license.badgeName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                let licenseBadgeStr = "![\(settings.license.badgeName)](https://img.shields.io/badge/License-\(webEscapedName)-\(settings.license.badgeColour).svg?style=flat)"
                readmeContents += "[\(licenseBadgeStr)](LICENSE.md)\n"
            }
            
            readmeContents += "\nProject description goes here\n\n"
            
            readmeContents += "## Usage\n\n"
            readmeContents += "## Dependencies\n\n"
            readmeContents += "## Author\n\n"
            readmeContents += "* **\(XcodeProjectBuilders.UserDetails().displayName!)** - *Initial work* "
            if let r = settings.repository {
                readmeContents += " - " + r.readMEDescription
            }
            readmeContents += "\n\n"
            
            if !settings.license.isNone && !settings.license.displayName.isEmpty {
                readmeContents += "## License\n\n"
                readmeContents += "This project is licensed under \(settings.license.displayName) - see the [LICENSE.md](LICENSE.md) file for details.\n\n"
            }
            readmeContents += "## Acknowledgments\n"
            
            try readmeContents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
