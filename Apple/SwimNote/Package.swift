// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwimNote",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SwimNoteCore", targets: ["SwimNoteCore"]),
        .executable(name: "SwimNoteApp", targets: ["SwimNoteApp"]),
        .executable(name: "SwimNoteCoreChecks", targets: ["SwimNoteCoreChecks"])
    ],
    targets: [
        .target(
            name: "SwimNoteCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SwimNoteApp",
            dependencies: ["SwimNoteCore"]
        ),
        .executableTarget(
            name: "SwimNoteCoreChecks",
            dependencies: ["SwimNoteCore"]
        )
    ]
)
