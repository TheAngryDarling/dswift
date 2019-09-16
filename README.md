# Dynamic Swift
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

Dynamic Swift is a wrapper application for working with SwiftPM projects.  The primary purpose of this application is to allow developers to write code in swift that generates code (much like how other projects may use Python, Perl, or some other scripting language to generate code), this way its all in the same language.

For installation instructions click [here](INSTALL.md)

    Note: This project has a minimum requirement of Swift 4.0 

    Note: When adding new dswift files manually through Xcode, add a new Swift file making sure to set the proper target.  After the file is created then re-name the extension to .dswift.  Xcode won't allow you to set the target  afterwards if the file extension is not a known compilable file.

    The other way to add missing dswift files to the Xcode Project is to re-generate the project file with the following command: dswift package generate-xcodeproj

## Dynamic Swift Files (.dswift)

Dynamic Swift files work much like Active Server Pages (ASP) and Java Server Pages (JSP) files.  Anything not in a <%... %> block is treated as text that is put directly to the output file.
Supported bocks:

* <%...%>: Regular block
* <%! ... %>: Static Block - Code in here is declared outside the generator function.  This gives you access to declaring class properties, functions etc to use within the regular blocks
* <%=...%>: Inline block - Used as a simple output tool for writing data to the generator

## Dynamic Static Swift Files (.dswift-static)

Dynamic Static Swift files are JSON files that instruct the dswift application to load the contents of a specified file into the project as a static variable

```json
{
    "file": "{Relative path to file to load}",
    "namespace": "{Optional namespace path for extension}",
    "modifier": "{access modifier. public or internal}",
    "name": "{Name to give new struct object}",
    "type": "{load type.  binary or text or text(iana character set name)}"
}
```

## Usage

### Example Commands

* dswift --config <-- Generates default dswift config file at ~/.dswift.config if it doesn't already exist
* dswift build ... <-- Builds dswift files, then build swift
* dswift rebuild ... <-- Rebuilds ALL dswift files, then builds swift
* dswift test ... <-- Builds dswift files, then swift test
* dswift package init ... <-- Set up a new project (through swift), and if set in configuration, adds license file and updates readme file
* dswift package update <-- Updates dependencies (through swift), and if set in configuration, rebuilds Xcode Project file
* dswift package reset <-- Clears dependencies (through swift), clears dswift cached build files
* dswift package generate-xcodeproj <-- Generates Xcode Project file (through swift), add dswift scripts to project, and if set in configuration, sorts resources within project

### Example File (dswift)

```swift
/// Example File:

import Foundation

public class Example {
    <% for i in 0..<5 {%>
    public func testFunc<%=i%>() {
        print("This is function #<%=i%>")
    }
    <%}%>
}

// Output file:

//  This file was dynamically generated from '{file name}' by Dynamic Swift.  Please do not modify directly.

import Foundation

public class Example {
    public func testFunc0() {
        print("This is function #0")
    }
    public func testFunc1() {
        print("This is function #1")
    }
    public func testFunc2() {
        print("This is function #2")
    }
    public func testFunc3() {
        print("This is function #3")
    }
    public func testFunc4() {
        print("This is function #4")
    }
}
```

### Example File (dswift-static)

```json
{
    "file": "{Relative path to file to load}",
    "namespace": "{Optional namespace path for extension}",
    "modifier": "{access modifier. public or internal}",
    "name": "{Name to give new struct object}",
    "type": "{load type.  binary or text or text(iana character set name)}"
}
```

#### Example String File

dswift-file (no namespace)
```json
{
    "file": "string.file",
    "modifier": "public",
    "name": "Strings",
    "type": "text"
}
```

generated file (no namespace)

```swift
public struct Strings {
    private init() { }
    private static let string: String = """
...
"""
    public static var data: Data { return Strings.string.data(using: String.Encoding(rawValue: 4))! }
}
```

dswift-file (with namespace)

```json
{
    "file": "string.file",
    "namespace": "ClassName1.ClassName2"
    "modifier": "public",
    "name": "Strings",
    "type": "text"
}
```

generated file (with namespace)

```swift
public extension ClassName1.ClassName2 {
    struct Strings {
        private init() { }
        private static let string: String = """
...
"""
        public static var data: Data { return Strings.string.data(using: String.Encoding(rawValue: 4))! }
    }
}
```

#### Example Binary File

dswift-file (no namespace)
```json
{
    "file": "binary.file",
    "modifier": "public",
    "name": "Binary",
    "type": "binary"
}
```

generated file (no namespace)
```swift
public struct Binary {
    private init() { }
    private static let _value: [Int8] = [
    ...
    ]
    public static var data: Data { return Data(bytes: Binary._value) }
}
```

dswift-file (with namespace)
```json
{
    "file": "binary.file",
    "namespace": "ClassName1.ClassName2"
    "modifier": "public",
    "name": "Binary",
    "type": "binary"
}
```

generated file (with namespace)
```swift
public extension ClassName1.ClassName2 {
    struct Binary {
        private init() { }
        private static let _value: [Int8] = [
        ...
        ]
        public static var data: Data { return Data(bytes: Binary._value) }
    }
}
```

## Using Shell Completion Scripts

Dynamic Swift ships with completion scripts for both Bash and ZSH. These files should be generated in order to use them.

### Bash

Use the following commands to install the Bash completions to `~/.dswift-package-complete.bash` and automatically load them using your `~/.bash_profile` file.

```bash
dswift package generate-completion-script bash > ~/.dswift-package-complete.bash
echo -e "source ~/.dswift-package-complete.bash\n" >> ~/.dbash_profile
source ~/.dswift-package-complete.bash
```

Alternatively, add the following commands to your `~/.bash_profile` file to directly load completions:

```bash
# Source Dynamic Swift completion
if [ -n "`which dswift`" ]; then
    eval "`dswift package generate-completion-script bash`"
fi
```

### ZSH

Use the following commands to install the ZSH completions to `~/.zsh/_swift`. You can chose a different folder, but the filename should be `_swift`. This will also add `~/.zsh` to your `$fpath` using your `~/.zshrc` file.

```bash
mkdir ~/.zsh
swift package package generate-completion-script zsh > ~/.zsh/_dswift
echo -e "fpath=(~/.zsh \$fpath)\n" >> ~/.zshrc
compinit
```

## Dependencies

* **[Xcode Project](https://github.com/TheAngryDarling/SwiftXcodeProj)** - A collection of classes, methods, and properties for reading/writing Xcode projects
* **[Swift Patches](https://github.com/TheAngryDarling/SwiftPatches)** - A collection of classes, methods, and properties to fill in the gaps on older versions of swift so witing code for multiple versions of Swift is a little easier.
* **[Version Kit](https://github.com/TheAngryDarling/SwiftVersionKit)** - Provides the ability to store, parse, edit, and compare version strings

## Author

* **Tyler Anger** - *Initial work* - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

This project is licensed under Apache License v2.0 - see the [LICENSE.md](LICENSE.md) file for details
