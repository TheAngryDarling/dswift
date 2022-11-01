//
//  String+dswiftLibTests.swift
//  
//
//  Created by Tyler Anger on 2022-10-20.
//

import Foundation
import SwiftPatches

internal extension String {
    func randomElements<T>(count length: Int, using generator: inout T) -> String where T : RandomNumberGenerator {
        guard self.count > 0 else { return "" }
        guard self.count > 1 else { return String(repeating: self, count: length) }
        var rtn: String = ""
        while rtn.count < length {
            guard let ch = self.randomElement(using: &generator) else {
                return rtn
            }
            rtn.append(ch)
        }
        return rtn
    }
    func randomElements(count length: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return self.randomElements(count: length, using: &generator)
    }
    
    static func randomAlphaNumericString<T>(count length: Int, using generator: inout T) -> String where T: RandomNumberGenerator {
        let alphaNumericCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return alphaNumericCharacters.randomElements(count: length, using: &generator)
    }
    
    static func randomAlphaNumericString(count length: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return randomAlphaNumericString(count: length, using: &generator)
    }
}

