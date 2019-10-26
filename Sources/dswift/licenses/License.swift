//
//  License.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-23.
//

import Foundation

public struct Licenses {
    private init() { }
    
    internal static func defaultLicenseReadMe(license: DSwiftSettings.License) -> String {
        return """
Copyright \(Calendar.current.component(.year, from: Date())) \(settings.authorName ?? "")
This project is licensed under \(license.displayName) - see the [LICENSE.md](LICENSE.md) file for details
"""
    }
    internal static func defaultLicenseReadMe() -> String {
        return """
Copyright \(Calendar.current.component(.year, from: Date())) \(settings.authorName ?? "")
This project is licensed under the conditions provided in the [LICENSE.md](LICENSE.md) file
"""
    }
}
