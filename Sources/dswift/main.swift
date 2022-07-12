//
//  dswift-main.swift
//
//
//  Created by Tyler Anger on 2022-04-26.
//


import Foundation
import dswiftapp


var arguments = ProcessInfo.processInfo.arguments

exit(DSwiftApp.execute(arguments: arguments))
