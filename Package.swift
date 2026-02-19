// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TallysPerfectPomo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TallysPerfectPomo",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "TallysPerfectPomoTests",
            dependencies: ["TallysPerfectPomo"],
            path: "Tests"
        )
    ]
)
