# MarkdownView Performance Improvement Options

## Current Bottleneck Analysis

| Bottleneck | Location | Impact |
|---|---|---|
| **WKWebView creation cost** | `reconfigure()` → new WKWebView | Cold start: 50-100+ ms (init) + 200-400 ms (first page load). Significant in List with multiple cells |
| **HTML/JS/CSS file loading** | `webView.load(URLRequest(url:))` | `render()` queued until page load completes |
| **JS bundle size** | `main.js` ~715KB (markdown-it + hljs 113 languages) | JS parse/execute adds to the 200-400 ms first-load cost |
| **IPC overhead** | Swift → JS (`callAsyncJavaScript`) → Swift (messageHandler) | ~0.4 ms per round-trip on modern devices; ~3-5 ms on older |
| **Height measurement → layout** | DOM measure → postMessage → invalidateIntrinsicContentSize | Frequent layout recalculation in List |
| **Memory per instance** | WKWebView WebContent process | 100-200+ MB per WKWebView without shared ProcessPool |

## Options

### A. Pure Swift (Remove WKWebView entirely)

**Approach:** Parse with cmark-gfm (C) or swift-markdown (Apple) → Render with NSAttributedString / SwiftUI Text / TextKit 2

**Available parser ecosystem:**
- **cmark-gfm** — C reference implementation. Parses Markdown version of *War and Peace* in ~127ms. 10,000x faster than Markdown.pl. Extensively fuzz-tested. Underlies both Apple's `AttributedString(markdown:)` and `swift-markdown`.
- **swift-markdown** (Apple) — Swift-idiomatic wrapper over cmark-gfm. Returns thread-safe, copy-on-write AST. Used by Swift-DocC. Parser only — rendering must be built.
- **Apple's `AttributedString(markdown:)`** (iOS 15+) — Parses GFM via cmark-gfm internally. SwiftUI `Text` only renders **inline** elements (bold, italic, strikethrough, code, links). Block-level elements (headers, lists, tables, code blocks) are parsed into `presentationIntent` attributes but **not visually rendered** by `Text`. This limitation persists through iOS 18.

**Available rendering approaches:**
- **Markdownosaur** (by Christian Selig) — swift-markdown → `NSAttributedString`. More customizable than `AttributedString(markdown:)`.
- **LiYanan2004/MarkdownView** — swift-markdown → recursive SwiftUI views via Layout protocol. Initial render ~400+ ms. Adopted by X (Grok) and Hugging Face Chat.
- **MarkdownDisplayView** — swift-markdown → TextKit 2 rendering. Claims ~270 ms initial render. Supports async rendering and incremental diff-based updates.
- **gonzalezreal/swift-markdown-ui (Textual)** — Known performance issues with long content, which prompted a ground-up rewrite.

**Pros:**
- Eliminates WKWebView startup cost (biggest bottleneck)
- Zero IPC — synchronous rendering possible
- Height measurement via `sizeThatFits` (no async round-trip)
- Significant memory reduction (no WebContent process)
- Full SwiftUI/UIKit integration, native accessibility
- Optimal for large numbers of cells in List/LazyVStack

**Lost capabilities:**
- **highlight.js 113-language syntax highlighting** — No equivalent exists in native Swift. TreeSitter-based approaches exist but with significantly less language coverage
- **markdown-it plugin ecosystem** — Footnotes, math (KaTeX), sub/sup, etc. Each plugin would need a native reimplementation
- **CSS-based styling freedom** — Custom CSS / external stylesheet injection impossible
- **HTML passthrough** (`html: true`) — Rendering raw HTML embedded in Markdown becomes difficult
- **Bootstrap-based rich table display**

**Benchmark context:**

| Approach | Cold Start | Warm Start |
|----------|-----------|------------|
| Native SwiftUI `Text` | Sub-millisecond | Sub-millisecond |
| Native `NSAttributedString` + UITextView | ~1-5 ms | Sub-millisecond |
| TextKit 2 (MarkdownDisplayView) | ~270 ms | Fast |
| SwiftUI Layout (LiYanan/MarkdownView) | ~400+ ms | Variable |
| WKWebView + markdown-it (this project) | 250-500 ms (cold) | 50-100 ms (warm) |

**Assessment:** Feature regression is **severe** as a replacement. The 113-language highlight.js support and plugin system are key differentiators. However, viable as a **separate lightweight target** (`MarkdownViewLite`) for use cases that don't need syntax highlighting or plugin extensibility.

---

### B. WKWebView Deep Optimization (Improve current architecture)

Maintain WKWebView-based architecture while systematically addressing known bottlenecks.

#### B-1. Shared WKProcessPool + Configuration Reuse

Share a static `WKProcessPool` across all instances to reduce WebContent process startup cost.

```swift
// Current: each reconfigure() creates a new WKWebViewConfiguration with its own process
// Proposed: share a single process pool
private static let sharedProcessPool = WKProcessPool()

// In configureWebView():
configuration.processPool = Self.sharedProcessPool
```

- **Impact:** Without shared pool, each WKWebView can consume 200+ MB. Shared pool significantly reduces memory. Also reduces process creation overhead when multiple MarkdownViews are used simultaneously.
- **Caveat:** Web views sharing a pool also share cookies, local storage, and session data. For this library's use case (local Markdown rendering only), this is a non-issue.
- **Implementation cost:** Low (few lines of code)

#### B-2. WKWebView Pre-warming (Pooling)

Pre-create WebViews and maintain a pool for instant dequeue.

- **Context:** WKWebView initialization blocks the main thread for 50-100+ ms. First page load adds another 200-400 ms. Pre-warming eliminates this wait.
- **Strategy:** Create hidden WKWebView instances early with `frame: .zero`, pre-load HTML template. When `reconfigure()` is called, dequeue a warm instance instead of creating from scratch.
- **Impact:** Eliminates WebView creation wait time; most effective for List scenarios
- **Implementation cost:** Medium (pool management, pre-loaded HTML, configuration handling)

#### B-3. JS Bundle Optimization

Current `main.js` is ~715KB with significant optimization potential.

- **Lazy-load highlight.js languages:** Bundle only 10-15 common languages initially; load rest on demand
- **Code splitting:** Use esbuild splitting for lighter initial load
- **Optional highlight.js:** Provide a lightweight build for use cases without syntax highlighting
- **Consideration:** JavaScriptCore uses a multi-tier JIT pipeline (LLInt → Baseline → DFG → FTL). Smaller initial JS means faster parsing into LLInt, and subsequent renders benefit from JIT warm-up. Bytecode caching (Safari 12.1+) means repeated loads are cheaper.

- **Impact:** Reduce initial JS parse/execution time; potentially under 200KB
- **Implementation cost:** Medium (esbuild config changes + lazy-load mechanism)

#### B-4. Inline HTML/JS/CSS (Eliminate file I/O)

Embed JS/CSS directly into HTML string and use `loadHTMLString()` instead of file-based loading.

- **Impact:** Eliminates file I/O. Single atomic load instead of HTML → then fetch JS/CSS.
- **Caveat:** `loadHTMLString` with `baseURL: nil` restricts local file references. Must set `baseURL` appropriately for relative paths to work.
- **Implementation cost:** Low-Medium

#### B-5. Eliminate Initial Render Wait (Embed Markdown in Initial Load)

Embed the initial markdown content directly in the HTML template to avoid the two-step process (load HTML → didFinish → render markdown).

- **Impact:** Removes one async round-trip from initial display. The `pendingRenderRequest` mechanism currently queues the first render until `didFinish` fires — this approach eliminates that wait entirely.
- **Implementation cost:** Low

---

### C. Hybrid Architecture

**Approach:** Parse in Swift (cmark-gfm); render via split path:
- **Simple Markdown** → NSAttributedString (native, instant)
- **Complex content (code blocks, raw HTML, plugin elements)** → WKWebView (full features)

**Pros:**
- Instant native display for simple text markdown
- Only complex content hits WKWebView
- Most List cells take the native path

**Cons:**
- Visual consistency between two rendering paths is difficult to maintain
- Native styling vs CSS styling divergence
- Complexity of routing logic
- Effectively doubles maintenance cost

**Real-world reference:** LiYanan2004/MarkdownView takes a partial hybrid approach — it uses SwiftUI views for most elements but embeds small WKWebView instances for SVG and math formulas. This works but adds per-element overhead.

**Assessment:** Theoretically attractive but **visual consistency risk** is the biggest concern.

---

### D. WKWebView + Offscreen Rendering (Snapshot)

**Approach:** Render in WKWebView, capture result as UIImage/CALayer, release WebView.

**Core limitation:** WKWebView only renders when visible in the view hierarchy. There is **no public API** for headless/off-screen rendering. The white-flash problem (content not rendered for the first moment after appearing) further complicates this.

**Assessment:** Too limited. Loss of interactivity (link taps, etc.) is fatal for most use cases.

---

### E. iOS 26+ SwiftUI WebView Conditional Architecture

**Approach:** Use `#available(iOS 26, *)` to provide a native SwiftUI `WebView` path on iOS 26+, while falling back to the current `UIViewRepresentable` wrapper on older versions.

#### iOS 26 SwiftUI WebView Overview

WWDC 2025 introduced `WebView` and `WebPage` as first-class SwiftUI citizens:

```swift
import WebKit

// WebPage: Observable state object managing the web view's lifecycle
let page = WebPage()

// WebView: Declarative SwiftUI view
WebView(page)
    .onNavigationDeciding { action in
        // Replaces WKNavigationDelegate.decidePolicyFor
    }
```

**Key APIs relevant to MarkdownView:**

| Current (UIViewRepresentable) | iOS 26 (SwiftUI WebView) |
|---|---|
| `WKWebView(frame:configuration:)` | `WebPage(configuration:)` + `WebView(page)` |
| `webView.load(URLRequest(url:))` | `page.load(URLRequest(url:))` |
| `webView.callAsyncJavaScript(...)` | `page.callAsyncJavaScript(...)` |
| `WKNavigationDelegate.decidePolicyFor` | `.onNavigationDeciding { }` modifier |
| `WKScriptMessageHandler` (`updateHeight`) | Same — via `WKWebViewConfiguration.userContentController` |
| `WKUserScript` (CSS/plugin injection) | Same — via `WebPage.Configuration` wrapping `WKWebViewConfiguration` |
| Manual Auto Layout constraints | Automatic SwiftUI sizing |
| `invalidateIntrinsicContentSize()` | `@Observable` state propagation |

#### Proposed Architecture

```
MarkdownUI (public SwiftUI API — unchanged)
├── iOS 26+: MarkdownWebView (SwiftUI native WebView)
│   └── WebPage + WebView
│       └── Same JS/CSS/HTML resources
└── iOS < 26: MarkdownUILegacy (UIViewRepresentable)
    └── MarkdownView (UIView + WKWebView)
        └── Same JS/CSS/HTML resources
```

```swift
// Public API — no breaking changes
public struct MarkdownUI: View {
    @Binding public var body: String
    // ... existing properties ...

    public var body: some View {
        if #available(iOS 26, *) {
            MarkdownWebView(
                markdown: $body,
                css: css, plugins: plugins,
                stylesheets: stylesheets, styled: styled,
                onTouchLink: onTouchLinkHandler,
                onRendered: onRenderedHandler
            )
        } else {
            MarkdownUILegacy(
                body: $body,
                css: css, plugins: plugins,
                stylesheets: stylesheets, styled: styled,
                onTouchLink: onTouchLinkHandler,
                onRendered: onRenderedHandler
            )
        }
    }
}

// iOS 26+ implementation
@available(iOS 26, *)
struct MarkdownWebView: View {
    @Binding var markdown: String
    @State private var page: WebPage

    init(/* ... */) {
        let configuration = WKWebViewConfiguration()
        // Reuse MarkdownScriptBuilder for CSS/plugin injection
        let contentController = scriptBuilder.makeContentController(configuration: renderConfig)
        // Attach MarkdownEventBridge for height updates
        eventBridge.attach(to: contentController)
        configuration.userContentController = contentController

        _page = State(initialValue: WebPage(configuration: configuration))
    }

    var body: some View {
        WebView(page)
            .onNavigationDeciding { action in
                // Link tap handling — replaces WKNavigationDelegate
            }
            .task {
                page.load(URLRequest(url: htmlUrl))
            }
            .onChange(of: markdown) { _, newValue in
                page.callAsyncJavaScript(
                    "window.renderMarkdown(payload)",
                    arguments: ["payload": ["markdown": newValue, "enableImage": true]]
                )
            }
    }
}
```

#### Impact Analysis

**What improves on iOS 26+:**

| Aspect | Current | iOS 26+ | Improvement |
|---|---|---|---|
| SwiftUI integration | UIViewRepresentable (bridging overhead) | Native SwiftUI view | Cleaner lifecycle, no Coordinator needed |
| Auto Layout | Manual 4-constraint setup in `MarkdownWebViewFactory` | Automatic SwiftUI layout | Eliminates constraint code |
| State sync | Closure-based (`onRendered`, `onTouchLink`) | `@Observable` WebPage + SwiftUI modifiers | More idiomatic reactive updates |
| Navigation handling | WKNavigationDelegate protocol conformance | `.onNavigationDeciding` modifier | Declarative, composable |
| Height propagation | `invalidateIntrinsicContentSize()` → UIKit layout pass | Direct SwiftUI state update | Fewer layout recalculations |

**What does NOT improve:**

| Aspect | Reason |
|---|---|
| WKWebView cold start (50-100+ ms) | SwiftUI `WebView` still uses WKWebView internally |
| First page load (200-400 ms) | Same WebContent process startup |
| JS bundle parse time (715KB) | Same JavaScript engine |
| IPC latency (~0.4 ms) | Same `callAsyncJavaScript` / `postMessage` mechanism |
| Memory per instance (100-200+ MB) | Same WebContent process |
| `updateHeight` message handler pattern | `WKScriptMessageHandler` still required — no SwiftUI equivalent |

**Key insight:** The performance bottleneck in MarkdownView is **WKWebView cold start + JS execution**, not the UIViewRepresentable bridging layer. The current `MarkdownUI.swift` is only 46 lines with minimal overhead. iOS 26 WebView improves **code quality and maintainability** but does not meaningfully improve **rendering performance**.

#### Shared Component Reuse

Both paths can share the same internal components:

| Component | Shared? | Notes |
|---|---|---|
| `MarkdownScriptBuilder` | Yes | Builds `WKUserContentController` identically for both paths |
| `MarkdownEventBridge` | Yes | Attaches to `userContentController` in both paths |
| `MarkdownRenderingConfiguration` | Yes | Same data model |
| `MarkdownWebViewFactory` | iOS < 26 only | iOS 26+ uses `WebView` directly, no manual constraints |
| HTML/JS/CSS Resources | Yes | Same bundle resources |
| `MarkdownView` (UIKit class) | iOS < 26 only | UIKit users still use this directly |

#### Risks and Concerns

1. **Dual code path maintenance** — Two SwiftUI rendering paths to test and maintain. Bug fixes may need to be applied in both places. Mitigated by shared internal components.
2. **WebPage lifecycle differences** — `WebPage`'s `@Observable` lifecycle may differ subtly from UIViewRepresentable's `makeUIView`/`updateUIView` cycle. Thorough testing needed for edge cases (rapid markdown updates, view appearance/disappearance).
3. **Height measurement on iOS 26+** — The `WKScriptMessageHandler` → `updateHeight` pattern is the same in both paths. SwiftUI WebView does not provide a built-in content height observation mechanism. Need to verify that attaching a message handler to `WebPage`'s configuration works identically.
4. **Beta API stability** — iOS 26 is in beta as of this writing. API surface may change before release.
5. **Minimum deployment target remains iOS 16** — The iOS 26 code path benefits only users running iOS 26+. Given iOS adoption curves, this path will serve a minority of users for at least 1-2 years after iOS 26 release.

#### Assessment

| Dimension | Rating | Notes |
|---|---|---|
| Performance impact | **Low** | Bottleneck is WKWebView/JS, not UIViewRepresentable |
| Code quality improvement | **Medium** | Cleaner SwiftUI integration, declarative navigation |
| Implementation cost | **Medium** | New SwiftUI component + testing both paths |
| Maintenance cost increase | **Medium** | Two SwiftUI paths (shared internals mitigate) |
| User-visible benefit | **Low** | No measurable performance difference for end users |
| Future-proofing value | **High** | Aligns with Apple's direction; UIViewRepresentable may eventually be deprecated |

**Verdict:** Worth implementing **after** B-series optimizations are done (Priority 6 in the roadmap below). The B-series changes improve performance for **all** iOS versions. This option improves code quality for iOS 26+ but doesn't address the core performance bottleneck.

---

## Recommended: Incremental Approach

Maintain current architecture and stack improvements in order of effort-to-impact ratio:

| Priority | Measure | Effect | Cost | Benefit scope |
|---|---|---|---|---|
| **1** | B-1: Shared ProcessPool | Reduce WKWebView memory and startup cost | Low | All iOS versions |
| **2** | B-5: Embed initial markdown in HTML load | Eliminate one async round-trip on first render | Low | All iOS versions |
| **3** | B-4: Inline HTML/JS/CSS | Eliminate file I/O; single atomic load | Low-Medium | All iOS versions |
| **4** | B-3: JS bundle optimization (hljs lazy-load) | Reduce initial ~715KB → ~200KB; faster JS parse | Medium | All iOS versions |
| **5** | B-2: WebView pooling | Eliminate 50-100+ ms cold start per instance in List | Medium | All iOS versions |
| **6** | E: iOS 26 conditional WebView | Cleaner SwiftUI integration; future-proof | Medium | iOS 26+ only |

**Rationale for Priority 6 placement of iOS 26 WebView:**
- Priorities 1-5 (B-series) directly reduce rendering latency and memory for **all** users on iOS 16+
- iOS 26 WebView improves code quality but does not improve rendering performance (same WKWebView underneath)
- iOS 26 adoption will be limited in the first 1-2 years; B-series optimizations benefit the entire user base immediately
- Implementing B-series first ensures the shared internals (`MarkdownScriptBuilder`, `MarkdownEventBridge`, resource loading) are already optimized before building the iOS 26 path on top

Pure Swift (A) is viable only as a **separate package** (`MarkdownViewLite`), not a replacement.

Hybrid (C) has high maintenance cost that likely doesn't justify the visual consistency challenges.

## Appendix: Benchmark References

- cmark: Markdown version of *War and Peace* in ~127ms ([swift-cmark benchmarks](https://github.com/swiftlang/swift-cmark/blob/gfm/benchmarks.md))
- CocoaMarkdown (cmark → NSAttributedString directly): ~8,500 ms / 1000 iterations, 20.3 MB peak ([Ezhes benchmark](https://ezh.es/1/01/benchmarking-popular-markdown-parsers-on-ios/))
- Down (cmark → HTML → NSAttributedString): ~47,000 ms / 1000 iterations, 1.12 GB spike ([Ezhes benchmark](https://ezh.es/1/01/benchmarking-popular-markdown-parsers-on-ios/))
- WKWebView cold start: 50-100+ ms init + 200-400 ms first page load ([Apple Developer Forums](https://developer.apple.com/forums/thread/733774))
- evaluateJavaScript round-trip: ~0.4 ms modern, ~3.6 ms older ([Persistent.info](https://blog.persistent.info/2015/01/wkwebview-communication-latency.html))
- MarkdownDisplayView (TextKit 2): ~270 ms initial render ([GitHub](https://github.com/zjc19891106/MarkdownDisplayView))
- LiYanan/MarkdownView (SwiftUI Layout): ~400+ ms initial render ([Fatbobman](https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/))
