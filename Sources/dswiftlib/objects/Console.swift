//
//  Console.swift
//  dswiftlib
//
//  Created by Tyler Anger on 2022-03-17.
//

import Foundation
import Dispatch
import CLIWrapper

public class Console {
    
    public enum MessageType {
        case error
        case plain
        case verbose
        case debug
    }
    
    public typealias PrintMessageTransformer = (_ message: String,
                                                _ file: String,
                                                _ line: Int,
                                                _ objectType: String?,
                                                _ funcname: String,
                                                _ messagType: MessageType,
                                                _ runingWithDebug: Bool) -> String
    
    public static let sharedOutputLock = NSLock()
    
    
    /// Indicator if can print error messages
    public let canPrintError: Bool
    /// Indicator if can print general messages
    public let canPrint: Bool
    /// Indicator if can print verbose messages
    public let canPrintVerbose: Bool
    /// Indicator if can print debug messages
    public let canPrintDebug: Bool
    /// The closure used to format any print messages
    private let printMessageTransformer: PrintMessageTransformer
    
    /// The dispatch queue used to order console output messages
    //public let printQueue: DispatchQueue
    
    private let _printOut: (String) -> Void
    private let _printErr: (String) -> Void
    
    /// A Console object that does not allow any output like /dev/null
    public static let null: Console = Console(canPrintError: false,
                                              canPrint: false)
    
    /// A Console object that does not allow any output like /dev/null
    public static let `default`: Console = Console()
    
    /// Create new Console Output Object
    /// - Parameters:
    ///   - canPrintError: Indicator if error prints are supported
    ///   - canPrint: Indicator if regular prints are supported
    ///   - canPrintVerbose: Indicator if verbose prints are supported
    ///   - canPrintDebug: Indicator if debug prints are supported
    ///   - printOut: The method used to print to STD Out
    ///   - printErr: The method used to print to STD Err
    ///   - printMessageTransformer: Closure used to format the message to print
    public init(canPrintError: Bool = true,
                canPrint: Bool = true,
                canPrintVerbose: Bool = false,
                canPrintDebug: Bool = false,
                printOut: @escaping (String) -> Void,
                printErr: @escaping (String) -> Void,
                printMessageTransformer: PrintMessageTransformer? = nil) {
        self.canPrintError = canPrintError
        self.canPrint = canPrint
        self.canPrintVerbose = canPrintVerbose
        self.canPrintDebug = canPrintDebug
        //self.printQueue = printQueue ?? Console.sharedOutputQueue
        self._printOut = printOut
        self._printErr = printErr
        self.printMessageTransformer = printMessageTransformer ?? Console.defaultPritnMessageTransformer
    }
    
    /// Create new Console Output Object
    ///
    /// This init provides default printOut (Swift.Print) and printErr(fput(..., stderr))
    /// - Parameters:
    ///   - canPrintError: Indicator if error prints are supported
    ///   - canPrint: Indicator if regular prints are supported
    ///   - canPrintVerbose: Indicator if verbose prints are supported
    ///   - canPrintDebug: Indicator if debug prints are supported
    ///   - printLock: The object used to synchronized output calls
    ///   - printMessageTransformer: Closure used to format the message to print
    public convenience init(canPrintError: Bool = true,
                canPrint: Bool = true,
                canPrintVerbose: Bool = false,
                canPrintDebug: Bool = false,
                printLock: Lockable? = nil,
                printMessageTransformer: PrintMessageTransformer? = nil) {
        
        func prt(_ str: String) {
            (printLock ?? Console.sharedOutputLock).lockingFor {
                Swift.print(str, terminator: "")
                fflush(stdout)
            }
        }
        func prtErr(_ str: String) {
            (printLock ?? Console.sharedOutputLock).lockingFor {
                _ = fputs(str, stderr)
                fflush(stderr)
            }
        }
        
        self.init(canPrintError: canPrintError,
                  canPrint: canPrint,
                  canPrintVerbose: canPrintVerbose,
                  canPrintDebug: canPrintDebug,
                  printOut: prt,
                  printErr: prtErr,
                  printMessageTransformer: printMessageTransformer)
    }
    
    private static func defaultPritnMessageTransformer(_ message: String,
                                                       _ file: String,
                                                       _ line: Int,
                                                       _ objectType: String?,
                                                       _ funcname: String,
                                                       _ messagType: MessageType,
                                                       _ runningWithDebug: Bool) -> String {
        guard runningWithDebug else {
            return message
        }
        var file = file
        if let r = file.range(of: "dswift/Sources/") {
            file = String(file[r.upperBound..<file.endIndex])
        }
        var objectPath = funcname
        if let objType = objectType {
            objectPath = objType + "." + funcname
        }
        return "\(file) - \(objectPath)[\(line)]: \(message)"
    }
}

public extension Console {
#if swift(>=5.3)
    /// Print a message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func print(_ items: Any...,
               separator: String = " ",
               terminator: String = "\n",
               file: String = #filePath,
               line: Int = #line,
               objectType: Any.Type? = nil,
               funcname: String = #function) {
        
   
        guard self.canPrint else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .plain,
                                                   self.canPrintDebug)
        
        self._printOut(message + terminator)
        
    }
    
    /// Print a message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object  calling the log method
    ///   - funcname: The function name calling the log method
    func print(_ items: Any...,
             separator: String = " ",
             terminator: String = "\n",
             file: String = #filePath,
             line: Int = #line,
             object: Any,
             funcname: String = #function) {
        
        guard self.canPrint else { return }
        
        self.print(items.map({ return "\($0)" }).joined(separator: separator),
                 separator: separator,
                   terminator: terminator,
                 file: file,
                 line: line,
                 objectType: type(of: object),
                 funcname: funcname)
    }
    /// Print a debug message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printDebug(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #filePath,
                  line: Int = #line,
                  objectType: Any.Type? = nil,
                  funcname: String = #function) {
        
        guard self.canPrintDebug else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .debug,
                                                   self.canPrintDebug)
        
        self._printOut(message + terminator)
    }
    /// Print a debug message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printDebug(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #filePath,
                  line: Int = #line,
                  object: Any,
                  funcname: String = #function) {
        
        guard self.canPrintDebug else { return }
        
        self.printDebug(items.map({ return "\($0)" }).joined(separator: separator),
                      separator: separator,
                        terminator: terminator,
                      file: file,
                      line: line,
                      objectType: type(of: object),
                      funcname: funcname)
    }
    /// Print a verbose message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printVerbose(_ items: Any...,
                    separator: String = " ",
                    terminator: String = "\n",
                    file: String = #filePath,
                    line: Int = #line,
                    objectType: Any.Type? = nil,
                    funcname: String = #function) {
        
        guard self.canPrintVerbose else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .verbose,
                                                   self.canPrintDebug)
        self._printOut(message + terminator)
    }
    /// Print a verbose message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printVerbose(_ items: Any...,
                    separator: String = " ",
                    terminator: String = "\n",
                    file: String = #filePath,
                    line: Int = #line,
                    object: Any,
                    funcname: String = #function) {
        
        guard self.canPrintVerbose else { return }
        
        self.printVerbose(items.map({ return "\($0)" }).joined(separator: separator),
                        separator: separator,
                          terminator: terminator,
                        file: file,
                        line: line,
                        objectType: type(of: object),
                        funcname: funcname)
    }
    
    /// Print an error message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printError(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #filePath,
                  line: Int = #line,
                  objectType: Any.Type? = nil,
                  funcname: String = #function) {
        
        guard self.canPrintError else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .error,
                                                   self.canPrintDebug)
        self._printErr(message + terminator)
    }
    
    /// Print an error message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printError(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #filePath,
                  line: Int = #line,
                  object: Any,
                  funcname: String = #function) {
        
        guard self.canPrintError else { return }
        
        self.printError(items.map({ return "\($0)" }).joined(separator: separator),
                      separator: separator,
                      terminator: terminator,
                      file: file,
                      line: line,
                      objectType: type(of: object),
                      funcname: funcname)
    }

#else

    /// Print a message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func print(_ items: Any...,
             separator: String = " ",
             terminator: String = "\n",
             file: String = #file,
             line: Int = #line,
             objectType: Any.Type? = nil,
             funcname: String = #function) {
        
        guard self.canPrint else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .plain,
                                                   self.canPrintDebug)
        self._printOut(message + terminator)
    }

    /// Print a message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object  calling the log method
    ///   - funcname: The function name calling the log method
    func print(_ items: Any...,
             separator: String = " ",
             terminator: String = "\n",
             file: String = #file,
             line: Int = #line,
             object: Any,
             funcname: String = #function) {
        
        guard self.canPrint else { return }
        
        self.print(items.map({ return "\($0)" }).joined(separator: separator),
                 separator: separator,
                   terminator: terminator,
                 file: file,
                 line: line,
                 objectType: type(of: object),
                 funcname: funcname)
    }
    /// Print a debug message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printDebug(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #file,
                  line: Int = #line,
                  objectType: Any.Type? = nil,
                  funcname: String = #function) {
        
        guard self.canPrintDebug else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .debug,
                                                   self.canPrintDebug)
        self._printOut(message + terminator)
    }
    /// Print a debug message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printDebug(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #file,
                  line: Int = #line,
                  object: Any,
                  funcname: String = #function) {
        
        guard self.canPrintDebug else { return }
        
        self.printDebug(items.map({ return "\($0)" }).joined(separator: separator),
                      separator: separator,
                        terminator: terminator,
                      file: file,
                      line: line,
                      objectType: type(of: object),
                      funcname: funcname)
    }
    /// Print a verbose message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printVerbose(_ items: Any...,
                    separator: String = " ",
                    terminator: String = "\n",
                    file: String = #file,
                    line: Int = #line,
                    objectType: Any.Type? = nil,
                    funcname: String = #function) {
        
        guard self.canPrintVerbose else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .verbose,
                                                   self.canPrintDebug)
        self._printOut(message + terminator)
    }
    /// Print a verbose message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printVerbose(_ items: Any...,
                    separator: String = " ",
                    terminator: String = "\n",
                    file: String = #file,
                    line: Int = #line,
                    object: Any,
                    funcname: String = #function) {
        
        guard self.canPrintVerbose else { return }
        
        self.printVerbose(items.map({ return "\($0)" }).joined(separator: separator),
                        separator: separator,
                          terminator: terminator,
                        file: file,
                        line: line,
                        objectType: type(of: object),
                        funcname: funcname)
    }

    /// Print an error message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - objectType: The object type calling the log method
    ///   - funcname: The function name calling the log method
    func printError(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #file,
                  line: Int = #line,
                  objectType: Any.Type? = nil,
                  funcname: String = #function) {
        
        guard self.canPrintError else { return }
        
        var strObjectType: String? = nil
        if let t = objectType {
            strObjectType = "\(t)"
        }
        let message = self.printMessageTransformer(items.map({ return "\($0)" }).joined(separator: separator),
                                                   file,
                                                   line,
                                                   strObjectType,
                                                   funcname,
                                                   .error,
                                                   self.canPrintDebug)
        ///  Xcode IDE gives warning here if I don't put _ = infrom of sync
        self._printErr(message + terminator)
    }

    /// Print an error message
    /// - Parameters:
    ///   - items: Zero or more items to print.
    ///   - separator: The string to print after all items have been printed. The default is a single space (`" "`).
    ///   - terminator: The string to print after all items have been printed. The default is a newline (`"\n"`).
    ///   - file: The file where the log was called. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the log was called. The default is the line number where you call this function.
    ///   - object: The object calling the log method
    ///   - funcname: The function name calling the log method
    func printError(_ items: Any...,
                  separator: String = " ",
                  terminator: String = "\n",
                  file: String = #file,
                  line: Int = #line,
                  object: Any,
                  funcname: String = #function) {
        
        guard self.canPrintError else { return }
        
        self.printError(items.map({ return "\($0)" }).joined(separator: separator),
                      separator: separator,
                        terminator: terminator,
                      file: file,
                      line: line,
                      objectType: type(of: object),
                      funcname: funcname)
    }

#endif
}
