//
//  Character+dswift.swift
//  dswift
//
//  Created by Tyler Anger on 2022-03-24.
//

import Foundation

#if !swift(>=5.0)
fileprivate extension Character {
    /// A Boolean value indicating whether this character represents whitespace, including newlines.
    var isWhitespace: Bool {
        return CharacterSet.whitespacesAndNewlines.contains(self.unicodeScalars.first!)
    }
}
#endif

internal extension Character {
    var isPeriod: Bool { return self == "." }
    
    var isAcceptableBeginningOfWord: Bool {
        let acceptableBeginningCharacters: [Character] = [" ", "'", "\"", "(", "[", "{"]
        return self.isWhitespace || acceptableBeginningCharacters.contains(self)
    }
    
    var isAcceptableEndingOfWord: Bool {
        let acceptableEndingCharacters: [Character] = [" ", "'", "\"", ")", "]", "}", "."]
        return self.isWhitespace || acceptableEndingCharacters.contains(self)
    }
}
