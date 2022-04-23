//
//  DSwiftInfo.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2021-12-08.
//

import Foundation
import VersionKit

/// Structure containing information about
/// The DSwift appliaction
public struct DSwiftInfo {
    /// The Application Display Name
    public let moduleName: String
    /// The application file name (name only, not path)
    public let appName: String
    /// The URL to the application Site
    public let url: String
    /// The current version of the application
    public let version: Version.SingleVersion
    
    /// Structure containing information about the DSwift application
    /// - Parameters:
    ///   - moduleName: The Application Display Name
    ///   - appName: The application file name (name only, not path)
    ///   - url: The URL to the application Site
    ///   - version: The current version of the application
    public init(moduleName: String = "Dynamic Swift",
                appName: String = "dswift",
                url: String = "https://github.com/TheAngryDarling/dswift",
                version: Version.SingleVersion) {
        self.moduleName = moduleName
        self.appName = appName
        self.url = url
        self.version = version
    }
}
