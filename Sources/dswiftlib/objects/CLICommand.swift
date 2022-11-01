//
//  CLICommand.swift
//  
//
//  Created by Tyler Anger on 2022-10-17.
//

import Foundation
import PathHelpers

public struct CLICommand {
    /// Path to the executable
    public var executable: FSPath
    /// Arguments for the executable
    public var arguments: [String]
    
    /// Create new Command object
    /// - Parameters:
    ///  - executable: Path to the executable
    ///  - arguments: The array arguments for the executable
    public init<Path: FSFullPath>(executable: Path, arguments: [String] = []) {
        if let p = executable as? FSPath {
            self.executable = p
        } else {
            self.executable = .init(executable.string)
        }
        self.arguments = arguments
    }
    /// Create new Command object
    /// - Parameters:
    ///  - executable: Path to the executable
    public init<Path: FSFullPath>(_ executable: Path) {
        self.init(executable: executable)
    }
    /// Create new Command object
    /// - Parameters:
    ///  - executable: Path to the executable
    ///  - arguments: The array arguments for the executable
    public init(executableURL: URL, arguments: [String] = []) {
        self.executable = .init(executableURL.path)
        self.arguments = arguments
    }
    /// Create new Command object
    /// - Parameters:
    ///  - executable: Path to the executable
    ///  - arguments: The array arguments for the executable
    public init(executablePath: String, arguments: [String] = []) {
        self.executable = .init(executablePath)
        self.arguments = arguments
    }
}

extension CLICommand: Equatable {
    public static func ==(lhs: CLICommand, rhs: CLICommand) -> Bool {
        return lhs.executable == rhs.executable &&
               lhs.arguments == rhs.arguments
    }
}

extension CLICommand: Codable {
    private enum CodingKeys: String, CodingKey {
        case executable
        case arguments
    }
    public init(from decoder: Decoder) throws {
        if let svc = try? decoder.singleValueContainer(),
           let str = try? svc.decode(String.self) {
            self.executable = .init(str)
            self.arguments = []
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.executable = .init(try c.decode(String.self, forKey: .executable))
            self.arguments = try c.decode([String].self, forKey: .arguments)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        if self.arguments.isEmpty {
            var svc = encoder.singleValueContainer()
            try svc.encode(self.executable.string)
        } else {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(self.executable.string, forKey: .executable)
            try c.encode(self.arguments, forKey: .arguments)
            
        }
    }
}
