# Dynamic Swift

![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)
[![Docker](https://img.shields.io/badge/container-Docker-blue.svg?style=flat)](https://cloud.docker.com/u/theangrydarling/repository/docker/theangrydarling/dswift)

Dynamic Swift is a wrapper application for working with SwiftPM projects.  The primary purpose of this application is to allow developers to write code in swift that generates code (much like how other projects may use Python, Perl, or some other scripting language to generate code), this way its all in the same language.

For installation instructions click [here](INSTALL.md)
For configuration instructions click [here](CONFIG.md)

> **Notes:**
>
> This project has a minimum requirement of Swift 4.0
>
> When adding new dswift files manually through Xcode, add a new Swift file making sure to set the proper target.  After the file is created then re-name the extension to .dswift.  Xcode won't allow you to set the target  afterwards if the file extension is not a known compilable file.
>
> The other way to add missing dswift files to the Xcode Project is to re-generate the project file with the following command: dswift package generate-xcodeproj

## Dynamic Swift Files (.dswift)

Dynamic Swift files work much like Active Server Pages (ASP) and Java Server Pages (JSP) files.  Anything not in a <%... %> block is treated as text that is put directly to the output file.
Supported bocks:

* <%...%>: Regular block
* <%! ... %>: Static Block - Code in here is declared outside the generator function.  This gives you access to declaring class properties, functions etc to use within the regular blocks
* <%!! ... %>: Global Block - Code here is declared outside of the generator class
* <%=...%>: Inline block - Used as a simple output tool for writing data to the generator
* <%@include file="..." onlyOnce="true|false" quiet="true|false" %>: Include dswift - Used to include an additional dswift file (dswiftInclude) into the given dswift file
    * **file** (\* Required): The dswift file to include.  (Best name it .dswiftInclude or .dswift-include so that it doesn't get processed as a standalone dswift file during 'dswift build')
    * **onlyOnce** (\* Optional): Indicating if the file should only be included once even if referenced to be included again somewhere else from within the file or any included files called (Much like #ifndef {FILE_NAME_H} #define {FILE_NAME_H}  {FILE_CODE} #endif)
    * **quiet** (\* Optional): Indicator if should hide include indicator comments within generated files
* <%@include folder="..." extensionMapping="rawswift:swift;...." filter="{regex}" quiet="true|false" %>: Include Folder - Used to include the contents of a folder into the project that builds the dswift file.  
    * **folder** (\* Required): The folder to copy.
    * **extensionMapping** (\* Optional): A ';' separated array of file exetension mappings. Main use is to map other extensions into swift files so they can be used in the include but are not direclty compiled within the main project
    * **filter** (\* Optional): Regular Expression pattern used to match the source path to determin if the source resource should be copied or not
    * **quiet** (\* Optional): Indicator if should hide include indicator comments within generated files
* <%@include package="https://github.com/... .git" from="1.0.0" packageName="name" packageNames="name1,name2" quiet="true|false" %>: Include Package - Used to include a package dependancy to the compiling of the dswift file.  *Note:  Unlike the other includes, the package include does not check changes to the package when determining if a dswift file needs to be re-compiled.  Also, the package will be re-downloaded every time the dswift file needs to be compiled.*
    * **package** (\* Required): The URL to the package repository
    * **from** (\* Required): The version to use
    * **packageName** (\* Optional, Must use this or packageNames): The name of the package to import
    * **packageNames** (\* Optional, Must use this or packageName): A comma separated list of package names to import
    * **quiet** (\* Optional): Indicator if should hide include indicator comments within generated files

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
* dswift run ... <-- Builds dswift files, then swift run
* dswift package init ... <-- Set up a new project (through swift), and if set in configuration, adds license file and updates readme file
* dswift package update <-- Updates dependencies (through swift), and if set in configuration, rebuilds Xcode Project file
* dswift package reset <-- Clears dependencies (through swift), clears dswift cached build files
* dswift package generate-xcodeproj <-- Generates Xcode Project file (through swift), add dswift scripts to project, and if set in configuration, sorts resources within project

### Tags

#### Global Block of Code:

Code in the generator file but outside the generator class

```
<%!!
...
%>
```

#### Static Block of Code:

Code in the generator class but outside the generator method

```
<%!
...
%>
```

#### Basic Block of Code:

Code within the generator method

```
<%
...
%>
```

#### Inline output

Outputs the value resulting from the content of the block

```
<%=...%>
```

#### Include File

Include the content of a file into a dswift file

##### Attributes

* **file**: The path (perferable relative) to the file to include. (Required).  Note: you can use '<PROJECT_ROOT>' to reference the root of the project
* **quiet**: Bool (true|false) indicator if comments should be added to dswift built file indicating there was an included file.  (Optional) (Default: true)
* **onlyOnce**: Bool (true|false) indicator if the file should only be included once even if another tag tries to include it again. (Optional) (Default: false)

```
<%@include file="./file.to.include.dswiftInclude" onlyOnce="true" quiet="false" %>
```

#### Include Folder

Include the content of a folder in the building of the dswift file

##### Attributes

* **folder**: The path (perferable relative) to the folder to include. (Required).  Note: you can use '<PROJECT_ROOT>' to reference the root of the project
* **quiet**: Bool (true|false) indicator if comments should be added to dswift built file indicating there was an included file.  (Optional) (Default: true)
* **filter**: Regular Expression used to help filter which files to include from the folder
* **includeExtensions**: A comma separated list of file extensions to include. (Optional) (Default: all file extensions)
* **excludeExtensions**: A comma separated list of file extensions to exclude. (Optional) (Default: no file extensions)
* **extensionMapping**: A ; separated list of key:value pair of extension mappings to change. where key is the files current extenion and value is the new extension to change to.  This allows for files to be mapped to swift files for use in the dswift generation but not actually compiled when building the project itself. (Optional) 
* **propagateAttributes**: Bool (true|false) indicator if these attributes should apply to any sub folder includes (Optional) (Default: true)

```
<%@include folder="./folder.to.include/" quiet="false" extensionMapping="txt:swift" %>
```

#### Include Package

Include a GitHub Package in the building of a dswift file

##### Attributes

* **package**: The URL of the package to include. (Required).  
* **from**: The from version for the package. (Required)
* **packageNames**: A comma separated list of package names from the package at URL to include in the dswift build (Required or packageName Required)
* **packageNames**: A package name from the package at URL to include in the dswift build (Required or packageNames Required)
* **quiet**: Bool (true|false) indicator if comments should be added to dswift built file indicating there was an included file.  (Optional) (Default: true)

```
<%@include package="https://github.com/TheAngryDarling/SwiftCodeTimer.git" from="1.0.1" packageName="CodeTimer" %>
```

#### Reference File

Tells dswift that this dswift file references another file so dswift should check it for modifications to determin if the dswift file should be rebuilt

##### Attributes

* **file**: The path (perferable relative) to the file to include. (Required).  Note: you can use '<PROJECT_ROOT>' to reference the root of the project

```
<%@reference file="./file.to.include.dswiftInclude" %>
```

#### Reference Folder

Tells dswift that this dswift file references another folder so dswift should check it for modifications to determin if the dswift file should be rebuilt 

##### Attributes

* **folder**: The path (perferable relative) to the folder to include. (Required).  Note: you can use '<PROJECT_ROOT>' to reference the root of the project
* **filter**: Regular Expression used to help filter which files to include from the folder
* **includeExtensions**: A comma separated list of file extensions to include. (Optional) (Default: all file extensions)
* **excludeExtensions**: A comma separated list of file extensions to exclude. (Optional) (Default: no file extensions)
* **propagateAttributes**: Bool (true|false) indicator if these attributes should apply to any sub folder includes (Optional) (Default: true)

```
<%@reference folder="./folder.to.include/" %>
```

### Example File (dswift)

```swift
/// Example DSwift Include File A.dswiftInclude
public class IncludeClass {
    ...
}

/// Example DSwift Include File B.dswiftInclude
print("This is an include method")


/// Example File:

import Foundation

public class Example {
    <%@include file="Include File A.dswiftInclude" onlyOnce="true" %>
    <%@include file="Include File A.dswiftInclude" %>
    <% for i in 0..<5 {%>
    public func testFunc<%=i%>() {
        <%@include file="Include File B.dswiftInclude" quiet="true" %>
        print("This is function #<%=i%>")
    }
    <%}%>
}

// Output file:

//  This file was dynamically generated from '{file name}' by Dynamic Swift.  Please do not modify directly.

import Foundation

public class Example {
    /* *** Begin Included 'Include File A.dswiftInclude' *** */
public class IncludeClass {
    ...
}

    /* *** End Include 'Include File A.dswiftInclude' *** */
    /* *** Begin Included Include File A.dswiftInclude' *** */
    /* *** Already included elsewhere *** */
    /* *** End Include 'Include File A.dswiftInclude' *** */
    public func testFunc0() {
        print("This is an include method")

        print("This is function #0")
    }
    public func testFunc1() {
        print("This is an include method")

        print("This is function #1")
    }
    public func testFunc2() {
        print("This is an include method")

        print("This is function #2")
    }
    public func testFunc3() {
        print("This is an include method")

        print("This is function #3")
    }
    public func testFunc4() {
        print("This is an include method")

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
    public static let encoding: String.Encoding = String.Encoding(rawValue: 4)
    public static var data: Data { return Strings.string.data(using: encoding)! }
}
```

dswift-file (with namespace)

```json
{
    "file": "string.file",
    "namespace": "ClassName1.ClassName2",
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
        public static let encoding: String.Encoding = String.Encoding(rawValue: 4)
        public static var data: Data { return Strings.string.data(using: encoding)! }
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
    "namespace": "ClassName1.ClassName2",
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
* **[BasicCodableHelpers](https://github.com/TheAngryDarling/SwiftBasicCodableHelpers)** - Provides helper classes and methods when encoding/decoding
* **[RegEx](https://github.com/TheAngryDarling/SwiftRegEx)** - Provides a Swift wrapper around the NSRegularExpression class that handles switching between NSRange and Range
* **[CLIWrapper](https://github.com/TheAngryDarling/SwiftCLIWrapper)** - Classes and objects used to wrap a CLI application.
* **[SynchronizeObjects](https://github.com/TheAngryDarling/SwiftSynchronizeObjects)** - Provides helper objects for generialzing object synchronization

## Author

* **Tyler Anger** - *Initial work* - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

This project is licensed under Apache License v2.0 - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* **[Pinecone](https://stackoverflow.com/questions/24041554/how-can-i-output-to-stderr-with-swift)** - Pinecone's example about how to print text to STD Err
