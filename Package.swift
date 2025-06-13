// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "MarkdownView",
            targets: ["MarkdownView"]
        ),
    ],
    targets: [
        .target(
            name: "MarkdownView",
            path: "Sources/MarkdownView",
            exclude: [
                "Resources/main.js.LICENSE.txt"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "MarkdownViewTests",
            dependencies: ["MarkdownView"],
            path: "Tests/MarkdownViewTests"
        )
    ],
    swiftLanguageVersions: [.v6]
)
