//
//  print.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation

//let verboseOverrideFlag: Bool = false
/// Indicator if we are running in verbose mode
var verboseFlag: Bool = false
func verbosePrint(_ items: Any..., separator: String = "", terminator: String = "\n") {
    if settings.isVerbose || verboseFlag {
        var msg: String = ""
        for (i, v) in items.enumerated() {
            if i > 0 { msg += separator }
            msg += "\(v)"
        }
        
        print(msg, separator: separator, terminator: terminator)
    }
}

// https://stackoverflow.com/questions/24041554/how-can-i-output-to-stderr-with-swift

public struct STDErrOutputStream: TextOutputStream {
    static let instance = STDErrOutputStream()
    public mutating func write(_ string: String) {
        fputs(string, stderr)
    }
}

func errPrint(_ items: Any..., separator: String = "", terminator: String = "\n") {
    var msg: String = ""
    for (i, v) in items.enumerated() {
        if i > 0 { msg += separator }
        msg += "\(v)"
    }
    
    var errStream = STDErrOutputStream.instance
    print(msg, separator: separator, terminator: terminator, to: &errStream)
}

func verboseErrPrint(_ items: Any..., separator: String = "", terminator: String = "\n") {
    if settings.isVerbose || verboseFlag {
        var msg: String = ""
        for (i, v) in items.enumerated() {
            if i > 0 { msg += separator }
            msg += "\(v)"
        }
        
        errPrint(msg, separator: separator, terminator: terminator)
    }
}
