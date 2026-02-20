# AGENTS

Purpose
- This document is a technical map for quickly understanding which components render Markdown and how they relate to each other.
- It is written at a high level of abstraction, avoiding implementation details, to remain resilient to change.

## Technical Components

- UIKit Layer
  - MarkdownView (UIView)
    - Internal: WKWebView
    - Role: Loads web assets (HTML/CSS/JS) and renders Markdown
    - Input: Markdown string, options (CSS/Plugins/Stylesheets, styled flag)
    - Output/Events: Render completion (height notification), link tap events
- Web Layer (Bundled Assets)
  - HTML: styled.html / non_styled.html
    - Role: Base HTML for rendering (toggles between styled and unstyled)
  - JS: main.js
    - Role: Markdown-to-HTML conversion using markdown-it and highlight.js, provides the window.showMarkdown API, measures height and notifies native side
  - CSS: main.css
    - Role: Default styles (applied via styled.html)
- SwiftUI Layer
  - MarkdownUI (UIViewRepresentable)
    - Role: Bridge that makes MarkdownView usable from SwiftUI
    - I/O: Passes SwiftUI data (Markdown string) to the UIKit side; receives events (link taps, render completion) via closures

## Relationships (Data/Event Flow Overview)

1) Initialization / Configuration
- MarkdownView creates a WKWebView and configures the UserContentController
- Loads HTML (styled / non-styled) and web assets (JS/CSS) from the bundle

2) Markdown Delivery
- Native code (Swift/SwiftUI) passes a Markdown string to MarkdownView
- MarkdownView forwards the string to the JS entry point (window.showMarkdown)

3) Web-Side Rendering
- main.js converts Markdown to HTML using markdown-it and highlight.js
- After DOM update, measures the document height

4) Bidirectional Events
- Web → Native
  - Notifies height changes via messages (intrinsic size update, render completion event)
  - Link taps are delegated to native for handling via WKNavigationDelegate
- Native → Web
  - Additional CSS / plugins / external stylesheets can be injected as UserScripts

## Extension Points (Overview)

- Styling
  - Inject CSS strings, inject external stylesheet links, toggle styled/non-styled mode
- Feature Extensions (Plugins)
  - Inject markdown-it-compatible plugin JS to add features (e.g., math, extended syntax)
- Event Handling
  - Control link tap behavior on the native side (e.g., open in external browser / in-app display)
  - Adjust layout in response to render completion (height) notifications
- Hosting
  - SwiftUI: Embed via UIViewRepresentable, with scroll responsibility separation
  - UIKit: Place directly as a UIView

## Platform / Distribution

- Target: iOS 13+
- Distribution: Swift Package Manager / CocoaPods / Carthage
- Bundle: HTML/CSS/JS are included as package Resources

This document covers only the roles of components and their connection points. For specific API names and internal implementation, refer to the source files (MarkdownView.swift, MarkdownUI.swift, Resources).
