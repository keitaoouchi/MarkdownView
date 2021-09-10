// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .iOS(.v13),
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
                .copy("Resources/styled.html"),
                .copy("Resources/non_styled.html"),
                .copy("Resources/main.js"),
                .copy("Resources/main.css")
            ]
        )
    ]
)
