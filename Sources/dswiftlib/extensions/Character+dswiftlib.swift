//
//  Character+dswiftlib.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2021-11-30.
//

import Foundation

#if !swift(>=5.0)
internal extension Character {
    /// A Boolean value indicating whether this character represents whitespace, including newlines.
    var isWhitespace: Bool {
        return CharacterSet.whitespacesAndNewlines.contains(self.unicodeScalars.first!)
    }
    /// A Boolean value indicating whether this character represents a newline.
    var isNewline: Bool {
        return CharacterSet.newlines.contains(self.unicodeScalars.first!)
    }
}
#endif
