# MarkdownView

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org/)
[![Version](https://img.shields.io/cocoapods/v/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)
[![License](https://img.shields.io/cocoapods/l/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

A WKWebView-based Markdown renderer for iOS. Converts Markdown to HTML using [markdown-it](https://markdown-it.github.io/) with syntax highlighting by [highlight.js](https://highlightjs.org/).

![GIF](https://github.com/keitaoouchi/MarkdownView/raw/master/sample.gif)

## Features

- Renders Markdown as styled HTML inside a native `UIView`
- Syntax highlighting for code blocks via highlight.js
- Dark mode support (automatic, via `prefers-color-scheme`)
- Custom CSS injection
- markdown-it plugin support (e.g., KaTeX math)
- External stylesheet loading
- Intrinsic content size for Auto Layout integration
- Link tap handling
- SwiftUI support via `MarkdownUI`

## Requirements

| Target | Version |
|--------|---------|
| iOS    | >= 16.0 |
| Swift  | >= 6.0  |

## Installation

MarkdownView is available through [Swift Package Manager](https://swift.org/package-manager/) or [CocoaPods](http://cocoapods.org).

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/keitaoouchi/MarkdownView.git", from: "2.0.0")
]
```

Alternatively, you can add the package directly via Xcode (File > Add Package Dependencies).

### CocoaPods

```ruby
pod "MarkdownView"
```

## Quick Start

### UIKit

```swift
import MarkdownView

let md = MarkdownView()
md.load(markdown: "# Hello World!")
```

### SwiftUI

```swift
import SwiftUI
import MarkdownView

struct ContentView: View {
    var body: some View {
        ScrollView {
            MarkdownUI(body: "# Hello World!")
                .onTouchLink { request in
                    print(request.url ?? "")
                    return false
                }
                .onRendered { height in
                    print(height)
                }
        }
    }
}
```

## API Reference

### MarkdownView (UIKit)

#### Initializers

| Signature | Description |
|-----------|-------------|
| `init()` | Creates a view with default settings. Call `load(markdown:)` to render content. |
| `init(css: String?, plugins: [String]?, stylesheets: [URL]? = nil, styled: Bool = true)` | Pre-configures a web view with CSS, plugins, and stylesheets. Use with `show(markdown:)` for efficient updates. |
| `init?(coder: NSCoder)` | Interface Builder support. |

#### Properties

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `isScrollEnabled` | `Bool` | `true` | Controls whether the internal web view scrolls. Set `false` when embedding in a `UIScrollView`. |
| `onTouchLink` | `((URLRequest) -> Bool)?` | `nil` | Called when a link is tapped. Return `true` to allow navigation, `false` to cancel. |
| `onRendered` | `((CGFloat) -> Void)?` | `nil` | Called when rendering completes. The parameter is the content height in points. |
| `intrinsicContentSize` | `CGSize` | — | Returns the measured content height. Updates automatically after rendering. |

#### Methods

| Signature | Description |
|-----------|-------------|
| `load(markdown: String?, enableImage: Bool = true, css: String? = nil, plugins: [String]? = nil, stylesheets: [URL]? = nil, styled: Bool = true)` | Loads Markdown by creating a new web view. Use this for one-shot rendering or when you need to change CSS/plugins. |
| `show(markdown: String)` | Updates the Markdown content on the existing web view. Requires prior initialization with `init(css:plugins:stylesheets:styled:)`. More efficient than `load` for repeated updates. |

**`load` vs `show`:** `load` recreates the web view on every call and accepts inline configuration. `show` reuses the existing web view, making it the better choice when displaying dynamic content that changes frequently.

### MarkdownUI (SwiftUI)

#### Initializer

```swift
MarkdownUI(
    body: String? = nil,
    css: String? = nil,
    plugins: [String]? = nil,
    stylesheets: [URL]? = nil,
    styled: Bool = true
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `body` | `String?` | `nil` | The Markdown string to render. |
| `css` | `String?` | `nil` | Custom CSS to inject. |
| `plugins` | `[String]?` | `nil` | Array of markdown-it plugin JavaScript strings. |
| `stylesheets` | `[URL]?` | `nil` | External stylesheet URLs to load. |
| `styled` | `Bool` | `true` | Use the built-in Bootstrap-based stylesheet. |

#### View Modifiers

| Modifier | Description |
|----------|-------------|
| `.onTouchLink(perform: @escaping (URLRequest) -> Bool)` | Called when a link is tapped. Return `true` to allow navigation, `false` to cancel. |
| `.onRendered(perform: @escaping (CGFloat) -> Void)` | Called when rendering completes with the content height. |

> **Note:** `MarkdownUI` disables internal scrolling. Wrap it in a `ScrollView` for scrollable content.

## Customization

### Custom CSS

Inject a CSS string to override the default styles:

```swift
// UIKit
let css = "body { background-color: #f0f0f0; } code { font-size: 14px; }"
let md = MarkdownView(css: css, plugins: nil)
md.show(markdown: "# Styled content")

// SwiftUI
MarkdownUI(body: "# Styled content", css: "body { background-color: #f0f0f0; }")
```

See [Example/Example/ViewController/CustomCss.swift](https://github.com/keitaoouchi/MarkdownView/blob/master/Example/Example/ViewController/CustomCss.swift) for a full example.

### Plugins

Add [markdown-it](https://markdown-it.github.io/) compatible plugins by passing the plugin JavaScript as a string. Each plugin must be self-contained with no external dependencies.

```swift
let katexPlugin = try! String(contentsOfFile: Bundle.main.path(forResource: "katex", ofType: "js")!)
let md = MarkdownView(css: nil, plugins: [katexPlugin])
md.show(markdown: "Inline math: $E = mc^2$")
```

See [Example/Example/ViewController/Plugins.swift](https://github.com/keitaoouchi/MarkdownView/blob/master/Example/Example/ViewController/Plugins.swift) for a full example, and the [sample plugin project](https://github.com/keitaoouchi/markdownview-sample-plugin) for building a compatible plugin library.

### External Stylesheets

Load CSS from remote URLs:

```swift
let url = URL(string: "https://example.com/custom.css")!
let md = MarkdownView(css: nil, plugins: nil, stylesheets: [url])
md.show(markdown: "# Remote-styled content")
```

### Styled vs Non-Styled Mode

By default, `styled: true` loads a Bootstrap-based stylesheet with highlight.js themes. Set `styled: false` to start with a blank canvas and apply your own CSS from scratch.

```swift
let md = MarkdownView(css: myCustomCSS, plugins: nil, styled: false)
```

### Dark Mode

The built-in stylesheet supports dark mode automatically via `prefers-color-scheme`. Text and link colors adapt to the system appearance. No additional configuration is needed.

To customize dark mode styles, inject CSS with a `prefers-color-scheme` media query:

```swift
let css = """
@media (prefers-color-scheme: dark) {
    body { background-color: #1a1a1a; }
    code { color: #e06c75; }
}
"""
let md = MarkdownView(css: css, plugins: nil)
```

## Example Project

The [Example/](https://github.com/keitaoouchi/MarkdownView/tree/master/Example) directory contains a full iOS app demonstrating UIKit usage, custom CSS, and plugin integration.

## Architecture

See [AGENTS.md](AGENTS.md) for a high-level overview of the component architecture and data flow.

## License

[bootstrap](http://getbootstrap.com/) is licensed under the [MIT License](https://github.com/twbs/bootstrap/blob/v4-dev/LICENSE).
[highlight.js](https://highlightjs.org/) is licensed under the [BSD-3-Clause License](https://github.com/highlightjs/highlight.js/blob/main/LICENSE).
[markdown-it](https://markdown-it.github.io/) is licensed under the [MIT License](https://github.com/markdown-it/markdown-it/blob/master/LICENSE).

MarkdownView is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
