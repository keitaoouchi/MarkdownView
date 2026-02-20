// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .iOS(.v16),
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
            resources: [
                .copy("Resources/styled.html"),
                .copy("Resources/non_styled.html"),
                .copy("Resources/main.js"),
                .copy("Resources/main.css")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
