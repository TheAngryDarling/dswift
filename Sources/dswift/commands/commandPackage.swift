//
//  commandPackage.swift
//  dswift
//
//  Created by Tyler Anger on 2019-07-21.
//

import Foundation
import XcodeProj
import PBXProj


fileprivate struct StringFile {
    private let path: String
    private var content: String = ""
    private var encoding: String.Encoding = .utf8
    
    public init(_ path: String) throws {
        let pth = NSString(string: path).expandingTildeInPath
        self.path = pth
        if FileManager.default.fileExists(atPath: pth) {
            self.content = try String(contentsOfFile: pth, usedEncoding: &self.encoding)
        }
    }
    
    public func save() throws {
        try self.content.write(toFile: self.path, atomically: true, encoding: self.encoding)
    }
    
    public func contains(_ element: String) -> Bool {
        return self.content.contains(element)
    }
    
    public static func +=(lhs: inout StringFile, rhs: String) {
        lhs.content += rhs
    }
}



extension Commands {
    
    static let BAHS_AUTO_COMPLETE: String = """
    #!/bin/bash

    _dswift()
    {
        declare -a cur prev
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        COMPREPLY=()
        if [[ $COMP_CWORD == 1 ]]; then
            _dswift_compiler
            COMPREPLY+=( $(compgen -W "build rebuild run package test" -- $cur) )
            return
        fi
        case ${COMP_WORDS[1]} in
            (build)
                _dswift_build 2
                ;;
            (rebuild)
                _dswift_build 2
                ;;
            (run)
                _dswift_run 2
                ;;
            (package)
                _dswift_package 2
                ;;
            (test)
                _dswift_test 2
                ;;
            (*)
                _dswift_compiler
                ;;
        esac
    }
    # Generates completions for swift build
    #
    # Parameters
    # - the start position of this parser; set to 1 if unknown
    function _dswift_build
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --build-tests --product --target --show-bin-path" -- $cur) )
            return
        fi
        case $prev in
            (-Xcc)
                return
            ;;
            (-Xswiftc)
                return
            ;;
            (-Xlinker)
                return
            ;;
            (-Xcxx)
                return
            ;;
            (--configuration|-c)
                COMPREPLY=( $(compgen -W "debug release" -- $cur) )
                return
            ;;
            (--build-path)
                _filedir
                return
            ;;
            (--chdir|-C)
                _filedir
                return
            ;;
            (--package-path)
                _filedir
                return
            ;;
            (--enable-prefetching)
            ;;
            (--disable-prefetching)
            ;;
            (--disable-sandbox)
            ;;
            (--version)
            ;;
            (--destination)
                _filedir
                return
            ;;
            (--verbose|-v)
            ;;
            (--no-static-swift-stdlib)
            ;;
            (--static-swift-stdlib)
            ;;
            (--build-tests)
            ;;
            (--product)
                return
            ;;
            (--target)
                return
            ;;
            (--show-bin-path)
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --build-tests --product --target --show-bin-path" -- $cur) )
    }

    # Generates completions for swift run
    #
    # Parameters
    # - the start position of this parser; set to 1 if unknown
    function _dswift_run
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --skip-build" -- $cur) )
            return
        fi
        case $prev in
            (-Xcc)
                return
            ;;
            (-Xswiftc)
                return
            ;;
            (-Xlinker)
                return
            ;;
            (-Xcxx)
                return
            ;;
            (--configuration|-c)
                COMPREPLY=( $(compgen -W "debug release" -- $cur) )
                return
            ;;
            (--build-path)
                _filedir
                return
            ;;
            (--chdir|-C)
                _filedir
                return
            ;;
            (--package-path)
                _filedir
                return
            ;;
            (--enable-prefetching)
            ;;
            (--disable-prefetching)
            ;;
            (--disable-sandbox)
            ;;
            (--version)
            ;;
            (--destination)
                _filedir
                return
            ;;
            (--verbose|-v)
            ;;
            (--no-static-swift-stdlib)
            ;;
            (--static-swift-stdlib)
            ;;
            (--skip-build)
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --skip-build" -- $cur) )
    }

    # Generates completions for swift package
    #
    # Parameters
    # - the start position of this parser; set to 1 if unknown
    function _dswift_package
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "update show-dependencies resolve fetch edit tools-version describe clean completion-tool generate-completion-script install-completion-script reset resolve-tool unedit init generate-xcodeproj dump-package -Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib" -- $cur) )
            return
        fi
        case $prev in
            (-Xcc)
                return
            ;;
            (-Xswiftc)
                return
            ;;
            (-Xlinker)
                return
            ;;
            (-Xcxx)
                return
            ;;
            (--configuration|-c)
                COMPREPLY=( $(compgen -W "debug release" -- $cur) )
                return
            ;;
            (--build-path)
                _filedir
                return
            ;;
            (--chdir|-C)
                _filedir
                return
            ;;
            (--package-path)
                _filedir
                return
            ;;
            (--enable-prefetching)
            ;;
            (--disable-prefetching)
            ;;
            (--disable-sandbox)
            ;;
            (--version)
            ;;
            (--destination)
                _filedir
                return
            ;;
            (--verbose|-v)
            ;;
            (--no-static-swift-stdlib)
            ;;
            (--static-swift-stdlib)
            ;;
        esac
        case ${COMP_WORDS[$1]} in
            (update)
                _dswift_package_update $(($1+1))
                return
            ;;
            (show-dependencies)
                _dswift_package_show-dependencies $(($1+1))
                return
            ;;
            (resolve)
                _dswift_package_resolve $(($1+1))
                return
            ;;
            (fetch)
                _dswift_package_fetch $(($1+1))
                return
            ;;
            (edit)
                _dswift_package_edit $(($1+1))
                return
            ;;
            (tools-version)
                _dswift_package_tools-version $(($1+1))
                return
            ;;
            (describe)
                _dswift_package_describe $(($1+1))
                return
            ;;
            (clean)
                _dswift_package_clean $(($1+1))
                return
            ;;
            (generate-completion-script)
                _dswift_package_generate-completion-script $(($1+1))
                return
            ;;
            (completion-tool)
                _dswift_package_completion-tool $(($1+1))
                return
            ;;
            (install-completion-script)
                _dswift_package_generate-completion-script $(($1+1))
                return
            ;;
            (reset)
                _dswift_package_reset $(($1+1))
                return
            ;;
            (resolve-tool)
                _dswift_package_resolve-tool $(($1+1))
                return
            ;;
            (unedit)
                _dswift_package_unedit $(($1+1))
                return
            ;;
            (init)
                _dswift_package_init $(($1+1))
                return
            ;;
            (generate-xcodeproj)
                _dswift_package_generate-xcodeproj $(($1+1))
                return
            ;;
            (dump-package)
                _dswift_package_dump-package $(($1+1))
                return
            ;;
        esac
        COMPREPLY=( $(compgen -W "update show-dependencies resolve fetch edit tools-version describe clean completion-tool generate-completion-script install-completion-script reset resolve-tool unedit init generate-xcodeproj dump-package -Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib" -- $cur) )
    }

    function _dswift_package_update
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    function _dswift_package_show-dependencies
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--format" -- $cur) )
            return
        fi
        case $prev in
            (--format)
                COMPREPLY=( $(compgen -W "text dot json" -- $cur) )
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--format" -- $cur) )
    }

    function _dswift_package_resolve
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--version --branch --revision" -- $cur) )
            return
        fi
        case $prev in
            (--version)
                return
            ;;
            (--branch)
                return
            ;;
            (--revision)
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--version --branch --revision" -- $cur) )
    }

    function _dswift_package_fetch
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    function _dswift_package_edit
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--revision --branch --path" -- $cur) )
            return
        fi
        case $prev in
            (--revision)
                return
            ;;
            (--branch)
                return
            ;;
            (--path)
                _filedir
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--revision --branch --path" -- $cur) )
    }

    function _dswift_package_tools-version
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--set --set-current" -- $cur) )
            return
        fi
        case $prev in
            (--set)
                return
            ;;
            (--set-current)
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--set --set-current" -- $cur) )
    }

    function _dswift_package_describe
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--type" -- $cur) )
            return
        fi
        case $prev in
            (--type)
                COMPREPLY=( $(compgen -W "text json" -- $cur) )
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--type" -- $cur) )
    }

    function _dswift_package_clean
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }
    
    function _dswift_package_generate-completion-script
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                COMPREPLY=( $(compgen -W "bash zsh" -- $cur) )
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    function _dswift_package_completion-tool
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                COMPREPLY=( $(compgen -W "generate-bash-script generate-zsh-script" -- $cur) )
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    function _dswift_package_reset
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    function _dswift_package_resolve-tool
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--type" -- $cur) )
            return
        fi
        case $prev in
            (--type)
                COMPREPLY=( $(compgen -W "text json" -- $cur) )
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--type" -- $cur) )
    }

    function _dswift_package_unedit
    {
        if [[ $COMP_CWORD == $(($1+0)) ]]; then
                return
        fi
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--force" -- $cur) )
            return
        fi
        case $prev in
            (--force)
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--force" -- $cur) )
    }

    function _dswift_package_init
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--type" -- $cur) )
            return
        fi
        case $prev in
            (--type)
                COMPREPLY=( $(compgen -W "empty library executable system-module" -- $cur) )
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--type" -- $cur) )
    }

    function _dswift_package_generate-xcodeproj
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "--xcconfig-overrides --enable-code-coverage --output" -- $cur) )
            return
        fi
        case $prev in
            (--xcconfig-overrides)
                _filedir
                return
            ;;
            (--enable-code-coverage)
            ;;
            (--output)
                _filedir
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "--xcconfig-overrides --enable-code-coverage --output" -- $cur) )
    }

    function _dswift_package_dump-package
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "" -- $cur) )
            return
        fi
        case $prev in
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "" -- $cur) )
    }

    # Generates completions for swift test
    #
    # Parameters
    # - the start position of this parser; set to 1 if unknown
    function _dswift_test
    {
        if [[ $COMP_CWORD == $1 ]]; then
            COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --skip-build --list-tests -l --parallel --specifier -s --filter" -- $cur) )
            return
        fi
        case $prev in
            (-Xcc)
                return
            ;;
            (-Xswiftc)
                return
            ;;
            (-Xlinker)
                return
            ;;
            (-Xcxx)
                return
            ;;
            (--configuration|-c)
                COMPREPLY=( $(compgen -W "debug release" -- $cur) )
                return
            ;;
            (--build-path)
                _filedir
                return
            ;;
            (--chdir|-C)
                _filedir
                return
            ;;
            (--package-path)
                _filedir
                return
            ;;
            (--enable-prefetching)
            ;;
            (--disable-prefetching)
            ;;
            (--disable-sandbox)
            ;;
            (--version)
            ;;
            (--destination)
                _filedir
                return
            ;;
            (--verbose|-v)
            ;;
            (--no-static-swift-stdlib)
            ;;
            (--static-swift-stdlib)
            ;;
            (--skip-build)
            ;;
            (--list-tests|-l)
            ;;
            (--parallel)
            ;;
            (--specifier|-s)
                return
            ;;
            (--filter)
                return
            ;;
        esac
        case ${COMP_WORDS[$1]} in
        esac
        COMPREPLY=( $(compgen -W "-Xcc -Xswiftc -Xlinker -Xcxx --configuration -c --build-path --chdir -C --package-path --enable-prefetching --disable-prefetching --disable-sandbox --version --destination --verbose -v --no-static-swift-stdlib --static-swift-stdlib --skip-build --list-tests -l --parallel --specifier -s --filter" -- $cur) )
    }

    _dswift_compiler()
    {
        if [[ `type -t _dswift_complete`"" == 'function' ]]; then
            _dswift_complete
        fi
    }

    complete -F _dswift dswift
    """
    static let ZSH_AUTO_COMPLETE: String = """
    #compdef dswift
    local context state state_descr line
    typeset -A opt_args

    _dswift() {
        _arguments -C \
            '(- :)--help[prints the synopsis and a list of the most commonly used commands]: :->arg' \
            '(-): :->command' \
            '(-)*:: :->arg' && return

        case $state in
            (command)
                local tools
                tools=(
                    'build:build sources into binary products'
                    'rebuild:rebuild dswift files then build sources into binary products'
                    'run:build and run an executable product'
                    'package:perform operations on Swift packages'
                    'test:build and run tests'
                )
                _alternative \
                    'tools:common:{_describe "tool" tools }' \
                    'compiler: :_dswift_compiler' && _ret=0
                ;;
            (arg)
                case ${words[1]} in
                    (build)
                        _dswift_build
                        ;;
                    (rebuild)
                        _dswift_build
                        ;;
                    (run)
                        _dswift_run
                        ;;
                    (package)
                        _dswift_package
                        ;;
                    (test)
                        _dswift_test
                        ;;
                    (*)
                        _dswift_compiler
                        ;;
                esac
                ;;
        esac
    }

    # Generates completions for swift build
    #
    # In the final compdef file, set the following file header:
    #
    #     #compdef _dswift_build
    #     local context state state_descr line
    #     typeset -A opt_args
    _dswift_build() {
        arguments=(
            "-Xcc[Pass flag through to all C compiler invocations]:Pass flag through to all C compiler invocations: "
            "-Xswiftc[Pass flag through to all Swift compiler invocations]:Pass flag through to all Swift compiler invocations: "
            "-Xlinker[Pass flag through to all linker invocations]:Pass flag through to all linker invocations: "
            "-Xcxx[Pass flag through to all C++ compiler invocations]:Pass flag through to all C++ compiler invocations: "
            "(--configuration -c)"{--configuration,-c}"[Build with configuration (debug|release) ]: :{_values '' 'debug[build with DEBUG configuration]' 'release[build with RELEASE configuration]'}"
            "--build-path[Specify build/cache directory ]:Specify build/cache directory :_files"
            "(--chdir -C)"{--chdir,-C}"[]: :_files"
            "--package-path[Change working directory before any other operation]:Change working directory before any other operation:_files"
            "--enable-prefetching[]"
            "--disable-prefetching[]"
            "--disable-sandbox[Disable using the sandbox when executing subprocesses]"
            "--version[]"
            "--destination[]: :_files"
            "(--verbose -v)"{--verbose,-v}"[Increase verbosity of informational output]"
            "--no-static-swift-stdlib[Do not link Swift stdlib statically]"
            "--static-swift-stdlib[Link Swift stdlib statically]"
            "--build-tests[Build both source and test targets]"
            "--product[Build the specified product]:Build the specified product: "
            "--target[Build the specified target]:Build the specified target: "
            "--show-bin-path[Print the binary output path]"
        )
        _arguments $arguments && return
    }

    # Generates completions for swift run
    #
    # In the final compdef file, set the following file header:
    #
    #     #compdef _dswift_run
    #     local context state state_descr line
    #     typeset -A opt_args
    _dswift_run() {
        arguments=(
            ":The executable to run: "
            "-Xcc[Pass flag through to all C compiler invocations]:Pass flag through to all C compiler invocations: "
            "-Xswiftc[Pass flag through to all Swift compiler invocations]:Pass flag through to all Swift compiler invocations: "
            "-Xlinker[Pass flag through to all linker invocations]:Pass flag through to all linker invocations: "
            "-Xcxx[Pass flag through to all C++ compiler invocations]:Pass flag through to all C++ compiler invocations: "
            "(--configuration -c)"{--configuration,-c}"[Build with configuration (debug|release) ]: :{_values '' 'debug[build with DEBUG configuration]' 'release[build with RELEASE configuration]'}"
            "--build-path[Specify build/cache directory ]:Specify build/cache directory :_files"
            "(--chdir -C)"{--chdir,-C}"[]: :_files"
            "--package-path[Change working directory before any other operation]:Change working directory before any other operation:_files"
            "--enable-prefetching[]"
            "--disable-prefetching[]"
            "--disable-sandbox[Disable using the sandbox when executing subprocesses]"
            "--version[]"
            "--destination[]: :_files"
            "(--verbose -v)"{--verbose,-v}"[Increase verbosity of informational output]"
            "--no-static-swift-stdlib[Do not link Swift stdlib statically]"
            "--static-swift-stdlib[Link Swift stdlib statically]"
            "--skip-build[Skip building the executable product]"
        )
        _arguments $arguments && return
    }

    # Generates completions for swift package
    #
    # In the final compdef file, set the following file header:
    #
    #     #compdef _dswift_package
    #     local context state state_descr line
    #     typeset -A opt_args
    _dswift_package() {
        arguments=(
            "-Xcc[Pass flag through to all C compiler invocations]:Pass flag through to all C compiler invocations: "
            "-Xswiftc[Pass flag through to all Swift compiler invocations]:Pass flag through to all Swift compiler invocations: "
            "-Xlinker[Pass flag through to all linker invocations]:Pass flag through to all linker invocations: "
            "-Xcxx[Pass flag through to all C++ compiler invocations]:Pass flag through to all C++ compiler invocations: "
            "(--configuration -c)"{--configuration,-c}"[Build with configuration (debug|release) ]: :{_values '' 'debug[build with DEBUG configuration]' 'release[build with RELEASE configuration]'}"
            "--build-path[Specify build/cache directory ]:Specify build/cache directory :_files"
            "(--chdir -C)"{--chdir,-C}"[]: :_files"
            "--package-path[Change working directory before any other operation]:Change working directory before any other operation:_files"
            "--enable-prefetching[]"
            "--disable-prefetching[]"
            "--disable-sandbox[Disable using the sandbox when executing subprocesses]"
            "--version[]"
            "--destination[]: :_files"
            "(--verbose -v)"{--verbose,-v}"[Increase verbosity of informational output]"
            "--no-static-swift-stdlib[Do not link Swift stdlib statically]"
            "--static-swift-stdlib[Link Swift stdlib statically]"
            '(-): :->command'
            '(-)*:: :->arg'
        )
        _arguments $arguments && return
        case $state in
            (command)
                local modes
                modes=(
                    'update:Update package dependencies'
                    'show-dependencies:Print the resolved dependency graph'
                    'resolve:Resolve package dependencies'
                    'fetch:'
                    'edit:Put a package in editable mode'
                    'tools-version:Manipulate tools version of the current package'
                    'describe:Describe the current package'
                    'clean:Delete build artifacts'
                    'generate-completion-script:Generate completion script (Bash or ZSH)'
                    'completion-tool:Generate completion script (generate-bash-script or generate-zsh-script)'
                    'install-completion-script:Install completion script (Bash or ZSH)'
                    'reset:Reset the complete cache/build directory'
                    'resolve-tool:'
                    'unedit:Remove a package from editable mode'
                    'init:Initialize a new package'
                    'generate-xcodeproj:Generates an Xcode project'
                    'dump-package:Print parsed Package.swift as JSON'
                )
                _describe "mode" modes
                ;;
            (arg)
                case ${words[1]} in
                    (update)
                        _dswift_package_update
                        ;;
                    (show-dependencies)
                        _dswift_package_show-dependencies
                        ;;
                    (resolve)
                        _dswift_package_resolve
                        ;;
                    (fetch)
                        _dswift_package_fetch
                        ;;
                    (edit)
                        _dswift_package_edit
                        ;;
                    (tools-version)
                        _dswift_package_tools-version
                        ;;
                    (describe)
                        _dswift_package_describe
                        ;;
                    (clean)
                        _dswift_package_clean
                        ;;
                    (generate-completion-script)
                        _dswift_package_generate-completion-script
                        ;;
                    (completion-tool)
                        _dswift_package_completion-tool
                        ;;
                    (install-completion-script)
                        _dswift_package_generate-completion-script
                        ;;
                    (reset)
                        _dswift_package_reset
                        ;;
                    (resolve-tool)
                        _dswift_package_resolve-tool
                        ;;
                    (unedit)
                        _dswift_package_unedit
                        ;;
                    (init)
                        _dswift_package_init
                        ;;
                    (generate-xcodeproj)
                        _dswift_package_generate-xcodeproj
                        ;;
                    (dump-package)
                        _dswift_package_dump-package
                        ;;
                esac
                ;;
        esac
    }

    _dswift_package_update() {
        arguments=(
        )
        _arguments $arguments && return
    }

    _dswift_package_show-dependencies() {
        arguments=(
            "--format[text|dot|json]: :{_values '' 'text[list dependencies using text format]' 'dot[list dependencies using dot format]' 'json[list dependencies using JSON format]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_resolve() {
        arguments=(
            ":The name of the package to resolve: "
            "--version[The version to resolve at]:The version to resolve at: "
            "--branch[The branch to resolve at]:The branch to resolve at: "
            "--revision[The revision to resolve at]:The revision to resolve at: "
        )
        _arguments $arguments && return
    }

    _dswift_package_fetch() {
        arguments=(
        )
        _arguments $arguments && return
    }

    _dswift_package_edit() {
        arguments=(
            ":The name of the package to edit: "
            "--revision[The revision to edit]:The revision to edit: "
            "--branch[The branch to create]:The branch to create: "
            "--path[Create or use the checkout at this path]:Create or use the checkout at this path:_files"
        )
        _arguments $arguments && return
    }

    _dswift_package_tools-version() {
        arguments=(
            "--set[Set tools version of package to the given value]:Set tools version of package to the given value: "
            "--set-current[Set tools version of package to the current tools version in use]"
        )
        _arguments $arguments && return
    }

    _dswift_package_describe() {
        arguments=(
            "--type[json|text]: :{_values '' 'text[describe using text format]' 'json[describe using JSON format]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_clean() {
        arguments=(
        )
        _arguments $arguments && return
    }

    _dswift_package_generate-completion-script() {
        arguments=(
            ": :{_values '' 'bash[generate completion script for Bourne-again shell]' 'zsh[generate completion script for Z shell]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_completion-tool() {
        arguments=(
            ": :{_values '' 'generate-bash-script[generate completion script for Bourne-again shell]' 'generate-zsh-script[generate completion script for Z shell]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_reset() {
        arguments=(
        )
        _arguments $arguments && return
    }

    _dswift_package_resolve-tool() {
        arguments=(
            "--type[text|json]: :{_values '' 'text[resolve using text format]' 'json[resolve using JSON format]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_unedit() {
        arguments=(
            ":The name of the package to unedit: "
            "--force[Unedit the package even if it has uncommited and unpushed changes.]"
        )
        _arguments $arguments && return
    }

    _dswift_package_init() {
        arguments=(
            "--type[empty|library|executable|system-module]: :{_values '' 'empty[generates an empty project]' 'library[generates project for a dynamic library]' 'executable[generates a project for a cli executable]' 'system-module[generates a project for a system module]'}"
        )
        _arguments $arguments && return
    }

    _dswift_package_generate-xcodeproj() {
        arguments=(
            "--xcconfig-overrides[Path to xcconfig file]:Path to xcconfig file:_files"
            "--enable-code-coverage[Enable code coverage in the generated project]"
            "--output[Path where the Xcode project should be generated]:Path where the Xcode project should be generated:_files"
        )
        _arguments $arguments && return
    }

    _dswift_package_dump-package() {
        arguments=(
        )
        _arguments $arguments && return
    }

    # Generates completions for swift test
    #
    # In the final compdef file, set the following file header:
    #
    #     #compdef _dswift_test
    #     local context state state_descr line
    #     typeset -A opt_args
    _dswift_test() {
        arguments=(
            "-Xcc[Pass flag through to all C compiler invocations]:Pass flag through to all C compiler invocations: "
            "-Xswiftc[Pass flag through to all Swift compiler invocations]:Pass flag through to all Swift compiler invocations: "
            "-Xlinker[Pass flag through to all linker invocations]:Pass flag through to all linker invocations: "
            "-Xcxx[Pass flag through to all C++ compiler invocations]:Pass flag through to all C++ compiler invocations: "
            "(--configuration -c)"{--configuration,-c}"[Build with configuration (debug|release) ]: :{_values '' 'debug[build with DEBUG configuration]' 'release[build with RELEASE configuration]'}"
            "--build-path[Specify build/cache directory ]:Specify build/cache directory :_files"
            "(--chdir -C)"{--chdir,-C}"[]: :_files"
            "--package-path[Change working directory before any other operation]:Change working directory before any other operation:_files"
            "--enable-prefetching[]"
            "--disable-prefetching[]"
            "--disable-sandbox[Disable using the sandbox when executing subprocesses]"
            "--version[]"
            "--destination[]: :_files"
            "(--verbose -v)"{--verbose,-v}"[Increase verbosity of informational output]"
            "--no-static-swift-stdlib[Do not link Swift stdlib statically]"
            "--static-swift-stdlib[Link Swift stdlib statically]"
            "--skip-build[Skip building the test target]"
            "(--list-tests -l)"{--list-tests,-l}"[Lists test methods in specifier format]"
            "--parallel[Run the tests in parallel.]"
            "(--specifier -s)"{--specifier,-s}"[]: : "
            "--filter[Run test cases matching regular expression, Format: <test-target>.<test-case> or <test-target>.<test-case>/<test>]:Run test cases matching regular expression, Format: <test-target>.<test-case> or <test-target>.<test-case>/<test>: "
        )
        _arguments $arguments && return
    }

    _dswift_compiler() {
    }

    _dswift
    """
    /// Post execution method for swift package
    static func commandPackage(_ args: [String]) throws -> Int32 {
        
        var arguments = args
        //arguments.removeFirst() //First parameter is the package param
        //guard let cmd = arguments.last?.lowercased() else { return 0 }
        
        if arguments.contains("--help") {
            return try commandPackageHelp(args)
        } else if arguments.contains("clean") {
            return try commandPackageClean(arguments, Commands.commandSwift(args))
        } else if arguments.contains("reset") {
            return try commandPackageReset(arguments, Commands.commandSwift(args))
        } else if arguments.contains("update") {
            return try commandPackageUpdate(arguments, Commands.commandSwift(args))
        } else if arguments.contains("generate-xcodeproj") {
            return try commandPackageGenXcodeProj(arguments, Commands.commandSwift(args))
        } else if arguments.contains("generate-completion-script") {
            return try commandPackageGenAutoScript(arguments)
        } else if arguments.contains("install-completion-script") {
            return try commandPackageInstallAutoScript(arguments)
        } else if arguments.count > 2 && arguments[arguments.count - 3].lowercased() == "init" {
            return try commandPackageInit(arguments, Commands.commandSwift(args))
        } else {
            return Commands.commandSwift(args)
        }
    }
    
    /// Clean any swift files build from dswift
    private static func cleanDSwiftBuilds() throws {
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath)
        verbosePrint("Package details loaded")
        
        for t in packageDetails.targets {
            
            verbosePrint("Looking at target: \(t.name)")
            let targetPath = URL(fileURLWithPath: t.path, isDirectory: true)
            try cleanFolder(fileExtension: dswiftFileExtension, folder: targetPath)
            
        }
    }
    
    
    /// Clean a folder of any swift files build from dswift
    static func cleanFolder(fileExtension: String, folder: URL) throws {
        //verbosePrint("Looking at path: \(folder.path)")
        let children = try FileManager.default.contentsOfDirectory(at: folder,
                                                                   includingPropertiesForKeys: nil)
        var folders: [URL] = []
        for child in children {
            if let r = try? child.checkResourceIsReachable(), r {
                
                guard !child.isPathDirectory else {
                    folders.append(child)
                    continue
                }
                guard child.isPathFile else { continue }
                
                if child.pathExtension.lowercased() == fileExtension.lowercased() {
                    let generatedFile = child.deletingPathExtension().appendingPathExtension("swift")
                    if let gR = try? generatedFile.checkResourceIsReachable(), gR {
                        
                        do {
                            
                            try FileManager.default.removeItem(at: generatedFile)
                            verbosePrint("Removed generated file '\(generatedFile.path)'")
                            
                        } catch {
                            print("Unable to remove generated file '\(generatedFile.path)'")
                            print(error)
                        }
                    }
                }
            }
            
            
            
        }
        
        for subFolder in folders {
            try cleanFolder(fileExtension: fileExtension, folder: subFolder)
        }
    }
    
    /// swift package clean catcher
    private static func commandPackageClean(_ args: [String], _ retCode: Int32) throws -> Int32 {
        try cleanDSwiftBuilds()
        return retCode
    }
    
    /// swift package update catcher
    private static func commandPackageUpdate(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 && settings.regenerateXcodeProject else { return retCode }
        
        return try processCommand(["package", "generate-xcodeproj"])
    }
    
    /// swift package reset catcher
    private static func commandPackageReset(_ args: [String], _ retCode: Int32) throws -> Int32 {
        try cleanDSwiftBuilds()
        return retCode
    }
    
    /*
    /// swift package generate-xcodeproj catcher
    private static func _commandPackageGenAutoScript(_ args: [String]) throws -> (String, Int32) {
        let task = Process()
        
        task.executable = URL(fileURLWithPath: settings.swiftPath)
        task.arguments = args
        
        let pipe = Pipe()
        defer {
            pipe.fileHandleForReading.closeFile()
            pipe.fileHandleForWriting.closeFile()
        }
        //#if os(macOS)
        //task.standardInput = FileHandle.nullDevice
        //#endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        try! task.execute()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var str = String(data: data, encoding: .utf8)!
        
        guard task.terminationStatus == 0 else {
            return (str, task.terminationStatus)
        }
        
        if args.last == "bash" || args.last == "generate-bash-script" {
            str = str.replacingOccurrences(of: "build run package test", with: "build rebuild run package test")
            str = str.replacingOccurrences(of: "clean generate-completion-script", with: "clean generate-completion-script install-completion-script")
            
            let checkBuildBlock: String = "(build)"
            let replaceBuildBlock: String = """
            (build)
                        _swift_build 2
                        ;;
                    (rebuild)
            """
             str = str.replacingOccurrences(of: checkBuildBlock, with: replaceBuildBlock)
            
            let checkCompletionBlock: String = "(generate-completion-script)"
            let replaceCompletiondBlock: String = """
            (generate-completion-script)
                        _swift_package_generate-completion-script $(($1+1))
                        return
                        ;;
                    (install-completion-script)
            """
            str = str.replacingOccurrences(of: checkCompletionBlock, with: replaceCompletiondBlock)
            
            
            str = str.replacingOccurrences(of: "complete -F _swift swift", with: "complete -F _swift \(dswiftAppName)")
            
            str = str.replacingOccurrences(of: "_swift", with: "_\(dswiftAppName)")
            
        } else if args.last == "zsh" || args.last == "generate-zsh-script" {
            str = str.replacingOccurrences(of: "#compdef swift", with: "#compdef \(dswiftAppName)")
            str = str.replacingOccurrences(of: "                'build:build sources into binary products'",
                                           with: "                'build:build sources into binary products'\n                'rebuild:rebuild \(dswiftAppName) files then build sources into binary products'")
            
            str = str.replacingOccurrences(of: "                'generate-completion-script:Generate completion script (Bash or ZSH)'",
                                           with: "                'generate-completion-script:Generate completion script (Bash or ZSH)'\n                'install-completion-script:Install completion script (Bash or ZSH)'")
            
            let checkBuildBlock: String = "(build)"
            let replaceBuildBlock: String = """
            (build)
                                _swift_build
                                ;;
                            (rebuild)
            """
            
            str = str.replacingOccurrences(of: checkBuildBlock, with: replaceBuildBlock)
            
            let checkCompletionBlock: String = "(generate-completion-script)"
            let replaceCompletionBlock: String = """
            (generate-completion-script)
                                _swift_package_generate-completion-script
                                ;;
                            (install-completion-script)
            """
            
            str = str.replacingOccurrences(of: checkCompletionBlock, with: replaceCompletionBlock)
            
            str = str.replacingOccurrences(of: "_swift", with: "_\(dswiftAppName)")
            
        }
        
        return (str, task.terminationStatus)
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageGenAutoScript(_ args: [String]) throws -> Int32 {
        let r = try _commandPackageGenAutoScript(args)
        print(r.0)
        return r.1
    }
   */
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageGenAutoScript(_ args: [String]) throws -> Int32 {
        if args.last == "bash" || args.last == "generate-bash-script" {
            print(BAHS_AUTO_COMPLETE)
            return 0
        } else if args.last == "zsh" || args.last == "generate-zsh-script" {
            print(ZSH_AUTO_COMPLETE)
            return 0
        } else if args.last == "--help" {
            let msg: String = """
            OVERVIEW: Generate completion script (Bash or ZSH)

            COMMANDS:
              flavor   Shell flavor (bash or zsh)
            """
            print(msg)
            return 0
        } else {
            errPrint("error: unknown value '\(args.last!)' for argument flavor; use --help to print usage")
            return 1
        }
    }
    
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageInstallAutoScript(_ args: [String]) throws -> Int32 {
        
        if args.last == "bash" || args.last == "generate-bash-script"  {
            var bashProfile: StringFile
            do { bashProfile = try StringFile("~/.bash_profile") }
            catch {
                errPrint("Unable to load ~/.bash_profile")
                return 1
            }
            guard !bashProfile.contains("which \(dswiftAppName)") else {
                print("Autocomplete script was previously installed")
                return 0
            }
            
            bashProfile += """
            
            # Source Dynamic Swift completion
            if [ -n "`which \(dswiftAppName)`" ]; then
            eval "`\(dswiftAppName) package generate-completion-script bash`"
            fi
            """
            
            do { try bashProfile.save() }
            catch {
                errPrint("Unable to save ~/.bash_profile")
                return 1
            }
            
            print("Autocomplete script installed.  Please run source ~/.bash_profile")
            
            return 0
        } else if args.last == "zsh" || args.last == "generate-zsh-script" {
            
            
            let zshFolderPath: String = NSString(string: "~/.zsh").expandingTildeInPath
            let zshProfilePath: String = NSString(string: "~/.zsh/_\(dswiftAppName)").expandingTildeInPath
            guard !FileManager.default.fileExists(atPath: zshProfilePath) else {
                print("Autocomplete script was previously installed")
                return 0
            }
            if !FileManager.default.fileExists(atPath: zshFolderPath) {
                do {
                    try FileManager.default.createDirectory(atPath: zshFolderPath, withIntermediateDirectories: false, attributes: nil)
                } catch {
                    errPrint("Unable to create ~/.zsh folder")
                    return 1
                }
            }
            
            do { try ZSH_AUTO_COMPLETE.write(toFile: zshProfilePath, atomically: true, encoding: .utf8) }
            catch {
                errPrint("Unable to save ~/.zsh/_\(dswiftAppName)")
                return 1
            }
            
            
            var zshProfile: StringFile
            do { zshProfile = try StringFile("~/.zshrc") }
            catch {
                errPrint("Unable to load ~/.zshrc")
                return 1
            }
            
            guard !zshProfile.contains("fpath=(~/.zsh $fpath)") else {
                return 0
            }
            
            zshProfile += "fpath=(~/.zsh $fpath)\n"
            
            do { try zshProfile.save() }
            catch {
                errPrint("Unable to save ~/.zshrc")
                return 1
            }
            
           print("Autocomplete script installed.  Please run compinit")
            
            return 0
         } else if args.last == "--help" {
            let msg: String = """
            OVERVIEW: Install completion script (Bash or ZSH)

            COMMANDS:
              flavor   Shell flavor (bash or zsh)
            """
            print(msg)
            return 0
        } else {
            errPrint("error: unknown value '\(args.last!)' for argument flavor; use --help to print usage")
            return 1
        }
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageHelp(_ args: [String]) throws -> Int32 {
        
        let task = Process()
        
        task.executable = URL(fileURLWithPath: settings.swiftPath)
        task.arguments = args
        
        let pipe = Pipe()
        defer {
            pipe.fileHandleForReading.closeFile()
            pipe.fileHandleForWriting.closeFile()
        }
        //#if os(macOS)
        //task.standardInput = FileHandle.nullDevice
        //#endif
        task.standardOutput = pipe
        task.standardError = pipe
        
        try! task.execute()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var str = String(data: data, encoding: .utf8)!
        
        str = str.replacingOccurrences(of: "USAGE: swift", with: "USAGE: \(dswiftAppName)")
        guard task.terminationStatus == 0 else {
            errPrint(str)
            return task.terminationStatus
        }
        
        str = str.replacingOccurrences(of: "  generate-completion-script\n                          Generate completion script (Bash or ZSH)",
                                       with: "  generate-completion-script\n                          Generate completion script (Bash or ZSH)\n  install-completion-script\n                          Install completion script (Bash or ZSH)")
        
        print(str)
        
        return task.terminationStatus
    }
    
    /// swift package init catcher
    private static func commandPackageInit(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 else { return retCode }
        guard (args.firstIndex(of: "--help") == nil) else { return retCode }
        
        try settings.readme.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("README.md"),
                                  for: args.last!.lowercased(),
                                  withName: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent)
        
        /// Setup license file
        try settings.license.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("LICENSE.md"))
        
        let gitIgnoreURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".gitignore")
        if FileManager.default.fileExists(atPath: gitIgnoreURL.path) {
            do {
                var file = try StringFile(gitIgnoreURL.path)
                if !file.contains("Package.resolved") {
                    file += "\nPackage.resolved"
                    
                    try file.save()
                }
            } catch { }
        }
        
        return retCode
    }
    
    /// swift package generate-xcodeproj catcher
    private static func commandPackageGenXcodeProj(_ args: [String], _ retCode: Int32) throws -> Int32 {
        guard retCode == 0 else { return retCode }
        guard (args.firstIndex(of: "--help") == nil) else { return retCode }
        
        var returnCode: Int32 = 0
        verbosePrint("Loading package details")
        let packageDetails = try PackageDescription(swiftPath: settings.swiftPath)
        verbosePrint("Package details loaded")
        
        let packageURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        //let packageName: String = packageURL.lastPathComponent
        
        let xCodeProjectURL = packageURL.appendingPathComponent("\(packageDetails.name).xcodeproj", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: xCodeProjectURL.path) else {
            errPrint("Project not found. \(xCodeProjectURL.path)")
            return 1
        }
        verbosePrint("Loading xcode project")
        let xcodeProject = try XcodeProject(fromURL: xCodeProjectURL)
        verbosePrint("Loaded xcode project")
        
        
        
        for tD in packageDetails.targets {
            //guard tD.type.lowercased() != "test" else { continue }
            let relativePath = tD.path.replacingOccurrences(of: FileManager.default.currentDirectoryPath, with: "")
            if let t = xcodeProject.targets.first(where: { $0.name == tD.name}),
                let nT = t as? XcodeNativeTarget,
                let targetGroup = xcodeProject.resources.group(atPath: relativePath)  {
                //let targetGroup = xcodeProject.resources.group(atPath: "Sources/\(tD.name)")!
                let rCode = try addDSwiftFilesToTarget(in: XcodeFileSystemURLResource(directory: tD.path),
                                           inGroup: targetGroup,
                                           havingTarget: nT,
                                           usingProvider: xcodeProject.fsProvider)
                if rCode != 0 {
                    returnCode = rCode
                }
                
                let rule = try nT.createBuildRule(name: "Dynamic Swift",
                                                   compilerSpec: "com.apple.compilers.proxy.script",
                                                   fileType: XcodeFileType.Pattern.proxy,
                                                   editable: true,
                                                   filePatterns: "*.dswift",
                                                   outputFiles: ["$(INPUT_FILE_DIR)/$(INPUT_FILE_BASE).swift"],
                                                   outputFilesCompilerFlags: nil,
                                                   script: "",
                                                   atLocation: .end)
                rule.script = """
                if ! [ -x "$(command -v \(dswiftAppName))" ]; then
                    echo "Error: \(dswiftAppName) is not installed.  Please visit \(dSwiftURL) to download and install." >&2
                    exit 1
                fi
                \(dswiftAppName) xcodebuild ${INPUT_FILE_PATH}
                """
            }
        }
 
 
        if settings.xcodeResourceSorting == .sorted {
            xcodeProject.resources.sort()
        }
        
        var indexAfterLastPackagFile: Int = 1
        
        
        let children = try xcodeProject.fsProvider.contentsOfDirectory(at: xcodeProject.projectFolder)
        for child in children {
            if child.lastPathComponent.compare("^Package\\@swift-.*\\.swift$", options: .regularExpression) == .orderedSame {
                try xcodeProject.resources.addExisting(child,
                                                       atLocation: .index(indexAfterLastPackagFile),
                                                       savePBXFile: false)
                indexAfterLastPackagFile += 1
            }
        }
        
        let additionalFiles: [String] = ["LICENSE.md", "README.md"]
        
        for file in additionalFiles {
            if let xcodeFile = children.first(where: { $0.lastPathComponent == file }) {
                try xcodeProject.resources.addExisting(xcodeFile,
                                                       atLocation: .index(indexAfterLastPackagFile),
                                                       savePBXFile: false)
                indexAfterLastPackagFile += 1
            }
        }
        
        //debugPrint(xcodeProject)
        try xcodeProject.save()
    
        return returnCode
    }
    
    /// Adds dswift files to Xcode Project
    internal static func addDSwiftFilesToTarget(in url: XcodeFileSystemURLResource,
                                                inGroup group: XcodeGroup,
                                                havingTarget target: XcodeTarget,
                                                usingProvider provider: XcodeFileSystemProvider) throws -> Int32 {
        func hasDSwiftSubFiles(in url: XcodeFileSystemURLResource, usingProvider provider: XcodeFileSystemProvider) throws -> Bool {
            let children = try provider.contentsOfDirectory(at: url)
            /*let children = try FileManager.default.contentsOfDirectory(atPath: url.path).map {
                return url.appendingPathComponent($0)
            }*/
            for child in children {
                // Check current dir for files
                if child.pathExtension.lowercased() == dswiftFileExtension, child.isFile /*child.isPathFile*/ {
                    return true
                }
            }
            for child in children {
                // Check sub dir for files
                //if child.isPathDirectory {
                if child.isDirectory {
                    if (try hasDSwiftSubFiles(in: child, usingProvider: provider)) { return true }
                }
            }
            return false
        }
        
        var rtn: Int32 = 0
        
        let children = try provider.contentsOfDirectory(at: url)
        /*let children = try FileManager.default.contentsOfDirectory(atPath: url.path).map {
            return url.appendingPathComponent($0)
        }*/
        
        for child in children {
            if child.pathExtension.lowercased() == dswiftFileExtension, child.isFile /*child.isPathFile*/ {
                if group.file(atPath: child.lastPathComponent) == nil {
                    // Only add the dswift file to the project if its not already there
                    let f = try group.addExisting(child,
                                                  copyLocally: true,
                                                  savePBXFile: false) as! XcodeFile
                    f.languageSpecificationIdentifier = "xcode.lang.swift"
                    target.sourcesBuildPhase().createBuildFile(for: f)
                    //print("Adding dswift file '\(child.path)'")
                }
                let swiftName = NSString(string: child.lastPathComponent).deletingPathExtension + ".swift"
                if let f = group.file(atPath: swiftName) {
                    var canRemoveSource: Bool = true
                    do {
                        let source = try String(contentsOf: URL(fileURLWithPath: f.fullPath))
                        if !source.hasPrefix("//  This file was dynamically generated from") {
                            rtn = 1
                            errPrint("Error: Source file '\(f.fullPath)' matches build file name for '\(child.path)' and is NOT a generated file")
                            canRemoveSource = false
                        }
                        
                    } catch { }
                    if canRemoveSource {
                        // Remove the generated swift file if its there
                        try f.remove(deletingFiles: false, savePBXFile: false)
                    }
                }
                //target.sourcesBuildPhase().createBuildFile(for: file)
            }
        }
        
        
        for child in children {
            if child.isDirectory, (try hasDSwiftSubFiles(in: child, usingProvider: provider)) {
                var childGroup = group.group(atPath: child.pathComponents.last!)
                if  childGroup == nil {
                    childGroup = try group.createGroup(withName: child.pathComponents.last!)
                }
                
                let rCode = try addDSwiftFilesToTarget(in: child,
                                                       inGroup: childGroup!,
                                                       havingTarget: target,
                                                       usingProvider: provider)
                
                if rtn == 0 && rCode > 0 { rtn = rCode }
            }
        }
        
        return rtn
        
    }
    
    
    
}
