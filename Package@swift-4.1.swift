// swift-tools-version:4.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "dswift",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "dswiftlib",
            targets: ["dswiftlib"]),
        .library(
            name: "dswiftapp",
            targets: ["dswiftapp"]),
        .executable(
            name: "dswift",
            targets: ["dswift"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        
        .package(url: "https://github.com/TheAngryDarling/SwiftXcodeProj.git",
                 from: "2.0.1"),
        .package(url: "https://github.com/TheAngryDarling/SwiftBasicCodableHelpers.git",
                 from: "1.1.7"),
    
        .package(url: "https://github.com/TheAngryDarling/SwiftPatches.git",
                 from: "2.0.9"),
        
        .package(url: "https://github.com/TheAngryDarling/SwiftVersionKit.git",
                 from: "1.0.9"),
        .package(url: "https://github.com/TheAngryDarling/SwiftRegEx.git",
                 from: "1.0.0"),
        .package(url: "https://github.com/TheAngryDarling/SwiftCodeTimer.git",
                 from: "1.0.1"),
        .package(url: "https://github.com/TheAngryDarling/SwiftCLICapture.git",
                 from: "3.0.1"),
        .package(url: "https://github.com/TheAngryDarling/SwiftCLIWrapper.git",
                 from: "2.0.0"),
        .package(url: "https://github.com/TheAngryDarling/SwiftSynchronizeObjects.git",
                    from: "1.0.3"),
        .package(url: "https://github.com/TheAngryDarling/SwiftJSONCommentCleaner.git",
                 from: "1.0.0"),
        .package(url: "https://github.com/TheAngryDarling/SwiftUnitTestingHelper.git",
                from: "1.0.5"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package
        // depends on.
        .target(name: "PathHelpers",
                dependencies: ["SwiftPatches"]),
        
        .target(name: "dswiftlib",
                dependencies: ["SynchronizeObjects",
                               "PathHelpers",
                               "CLICapture",
                               "CLIWrapper",
                               "BasicCodableHelpers",
                               "RegEx",
                               "SwiftPatches",
                               "VersionKit",
                               "XcodeProj",
                               "CodeTimer",
                               "JSONCommentCleaner"]),
        
            .target(name: "dswiftapp",
                    dependencies: ["dswiftlib",
                                   "PathHelpers",
                                   "CLIWrapper",
                                   "SwiftPatches",
                                   "VersionKit"]),
        
        .target(name: "dswift",
                dependencies: ["dswiftapp"]),
        
        .testTarget(name: "dswiftlibTests",
                    dependencies: ["dswiftlib",
                                   "dswiftapp",
                                   "UnitTestingHelper",
                                   "CodeTimer",
                                   "JSONCommentCleaner",
                                   "SwiftPatches"])
    ]
)

