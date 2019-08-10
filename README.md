# Dynamic Swift

Dynamic Swift is a wrapper application for working with SwiftPM projects.  The primary purpose of this application is to allow developers to write code in swift that generates code (much like how other projects may use Python, Perl, or some other scripting language to generate code), this way its all in the same language.

    Note: This project has a minimun requirement of Swift 4.0 

    Note: When adding new dswift files manually through Xcode, add a new Swift file making sure to set the proper target.  After the file is created then re-name the extension to .dswift.  Xcode won't allow you to set the target  afterwards if the file extension is not a known compilable file.

    The other way to add missing dswift files to the Xcode Project is to re-generate the project file with the following command: dswift package generate-xcodeproj

## Dynamic Swift Files (.dswift)

Dynamic Swift files work much like Active Server Pages (ASP) and Java Server Pages (JSP) files.  Anything not in a <%... %> block is treated as text that is put directly to the output file.
Supported bocks:

* <%...%>: Regular block
* <%! ... %>: Static Block - Code in here is declared outside the generator function.  This gives you access to declaring class properties, functions etc to use within the regular blocks
* <%=...%>: Inline block - Used as a simple output tool for writing data to the generator

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

### Example File

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
        print("This is function #0)
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

## Author

* **Tyler Anger** - *Initial work* - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

This project is licensed under Apache License v2.0 - see the [LICENSE.md](LICENSE.md) file for details
