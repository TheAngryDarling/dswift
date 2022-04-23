//
//  unlicense.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2019-07-24.
//

import Foundation

public extension Licenses {
    /// Returns the Unlicense license full text
    static func unlicense(authorName: String? = nil,
                          date: Date = Date()) -> String { return """
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org>
"""
    }
    /// Returns the Unlicense license full text
    static func unlicense(settings: DSwiftSettings,
                          date: Date = Date()) -> String {
        return unlicense(authorName: settings.authorName, date: date)
    }
    /// Returns the Unlicense license readme text
    static func unlicense_README(authorName: String? = nil,
                                 date: Date = Date()) -> String {
        return defaultLicenseReadMe(authorName: authorName,
                                    date: date,
                                    license: .unlicense)
    }
    /// Returns the Unlicense license readme text
    static func unlicense_README(settings: DSwiftSettings,
                                 date: Date = Date()) -> String {
        return unlicense_README(authorName: settings.authorName,
                                date: date)
    }
}
