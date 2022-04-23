//
//  mit.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-07-24.
//

import Foundation

public extension Licenses {
    /// Returns the MIT license full text
    static func mit(authorName: String? = nil,
                    date: Date = Date()) -> String { return """
MIT License

Copyright (c) \(Calendar.current.component(.year, from: date)) \(authorName ?? "")

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""
    }
    /// Returns the MIT license full text
    static func mit(settings: DSwiftSettings,
                    date: Date = Date()) -> String {
        
        return mit(authorName: settings.authorName, date: date)
    }
    /// Returns the MIT license readme text
    static func mit_README(authorName: String? = nil,
                           date: Date = Date()) -> String {
        return defaultLicenseReadMe(authorName: authorName, date: date, license: .mit)
    }
    /// Returns the MIT license readme text
    static func mit_README(settings: DSwiftSettings,
                           date: Date = Date()) -> String {
        return mit_README(authorName: settings.authorName, date: date)
    }
}
