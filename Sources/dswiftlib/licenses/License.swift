//
//  License.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-07-23.
//

import Foundation

public struct Licenses {
    private init() { }
    
    /// Returns the default license readme text
    public static func defaultLicenseReadMe(authorName: String? = nil,
                                              date: Date = Date(),
                                              license: DSwiftSettings.License) -> String {
        return """
*Copyright \(Calendar.current.component(.year, from: date)) \(authorName ?? "")*

This project is licensed under \(license.displayName) - see the [LICENSE.md](LICENSE.md) file for details
"""
    }
    /// Returns the default license readme text
    public static func defaultLicenseReadMe(settings: DSwiftSettings,
                                              date: Date = Date(),
                                              license: DSwiftSettings.License) -> String {
        return defaultLicenseReadMe(authorName: settings.authorName,
                                    date: date,
                                    license: license)
    }
    /// Returns the default license readme text
    public static func defaultLicenseReadMe(authorName: String? = nil,
                                              date: Date = Date()) -> String {
        func getAuthor() -> String {
            guard let a = authorName else { return "" }
            return " " + a
        }
        return """
*Copyright \(Calendar.current.component(.year, from: date))\(getAuthor())*

This project is licensed under the conditions provided in the [LICENSE.md](LICENSE.md) file
"""
    }
    
    /// Returns the default license readme text
    public static func defaultLicenseReadMe(settings: DSwiftSettings,
                                              date: Date = Date()) -> String {
        return defaultLicenseReadMe(authorName: settings.authorName, date: date)
    }
}
