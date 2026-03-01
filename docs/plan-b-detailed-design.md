# Plan B: WKWebView Deep Optimization — Detailed Design

This document provides implementation-ready specifications for each B-series optimization. Changes are ordered by priority (effort-to-impact ratio) and designed to be committed independently.

## Codebase Snapshot (as of design time)

```
Sources/MarkdownView/
├── MarkdownView.swift              # Public UIView class (273 lines)
├── MarkdownUI.swift                # SwiftUI UIViewRepresentable (46 lines)
├── MarkdownScriptBuilder.swift     # WKUserContentController builder (64 lines)
├── MarkdownEventBridge.swift       # WKScriptMessageHandler for height (19 lines)
├── MarkdownWebViewFactory.swift    # WKWebView creation + Auto Layout (28 lines)
└── Resources/
    ├── styled.html                 # HTML template with CSS link (12 lines)
    ├── non_styled.html             # HTML template without CSS (11 lines)
    ├── main.js                     # Bundled JS: markdown-it + hljs 113 langs (~715KB)
    └── main.css                    # Bundled CSS: bootstrap + gist + github + custom (~21KB)

webassets/
├── build.mjs                       # esbuild build script
├── package.json                    # Dependencies (markdown-it, highlight.js, markdown-it-emoji)
├── src/js/index.js                 # JS entry point (378 lines)
├── src/css/                        # Source CSS files (~26KB total)
└── tests/render.spec.js            # 16 Playwright tests
```

**Key data flow (current):**

```
MarkdownView.reconfigure()
  → WKWebViewConfiguration (new each time)
    → MarkdownScriptBuilder.makeContentController()  // CSS/plugin WKUserScripts
    → MarkdownEventBridge.attach()                    // updateHeight message handler
  → MarkdownWebViewFactory.makeWebView()              // WKWebView + Auto Layout
  → webView.load(URLRequest(url: styled.html))        // File-based load
  → [didFinish] → pendingRenderRequest fires
    → callAsyncJavaScript("window.renderMarkdown(payload)")
      → JS: markdown-it.render() → DOM update → hljs.highlightElement()
      → JS: postDocumentHeight() → webkit.messageHandlers.updateHeight.postMessage(height)
        → MarkdownEventBridge → onRendered callback → invalidateIntrinsicContentSize()
```

---

## B-1: Shared WKProcessPool + Configuration Reuse

### Problem

Each call to `reconfigure()` creates a new `WKWebViewConfiguration()` with an implicit new `WKProcessPool`. Each WKProcessPool spawns a separate WebContent process (100-200+ MB). Multiple `MarkdownView` instances in a List multiply this cost.

### Design

Add a static shared `WKProcessPool` to `MarkdownView` and apply it to every configuration.

### Changes

**File: `MarkdownView.swift`**

```swift
// Add at class level (after line 10):
private static let sharedProcessPool = WKProcessPool()
```

```swift
// In configureWebView(with:styled:) (around line 260), after creating configuration:
func configureWebView(with renderingConfiguration: MarkdownRenderingConfiguration, styled: Bool) {
    webView?.removeFromSuperview()
    isWebViewLoaded = false
    pendingRenderRequest = nil

    let configuration = WKWebViewConfiguration()
    configuration.processPool = Self.sharedProcessPool  // ← ADD THIS LINE
    let contentController = scriptBuilder.makeContentController(configuration: renderingConfiguration)
    eventBridge?.attach(to: contentController)
    configuration.userContentController = contentController
    // ... rest unchanged
}
```

### Impact

- **Memory:** Multiple `MarkdownView` instances share one WebContent process instead of each spawning its own.
- **Startup:** Second and subsequent instances skip WebContent process creation (~50-100 ms saved per instance).
- **Side effect:** Shared cookie/localStorage/session across instances. Non-issue for this library (local Markdown rendering only, no network state).

### Verification

- Create 3+ `MarkdownView` instances in an example project, observe memory in Instruments (Allocations). Compare before/after.
- Ensure all instances render correctly and independently.

### Estimated diff: ~3 lines changed in `MarkdownView.swift`

---

## B-5: Embed Initial Markdown in HTML Load

> **Note:** Prioritized before B-4 because it's simpler and addresses the most visible latency (first render delay).

### Problem

Current two-step process:
1. `reconfigure()` → `webView.load(URLRequest(url: styled.html))`
2. `didFinish` fires → `pendingRenderRequest` → `callAsyncJavaScript("window.renderMarkdown(payload)")`

The user sees a blank view until step 2 completes. The `pendingRenderRequest` mechanism exists solely to bridge this gap.

### Design

When `render()` is called before the WebView has finished loading (i.e., `isWebViewLoaded == false`), instead of queueing a `pendingRenderRequest`, embed the initial markdown directly into the HTML template and load it as a string via `loadHTMLString`. This eliminates the async round-trip: the JS executes `renderMarkdown` during the initial page load itself.

**Strategy:** Modify the HTML template at runtime to include a `<script>` tag that calls `renderMarkdown` with the initial content, then load via `loadHTMLString(_:baseURL:)`.

### Changes

**File: `MarkdownView.swift`**

Add a method to build the HTML string with embedded initial markdown:

```swift
private func buildInitialHTML(styled: Bool, markdown: String?, enableImage: Bool) -> (String, URL) {
    let htmlUrl = styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl
    let baseURL = htmlUrl.deletingLastPathComponent()

    guard let markdown, var htmlString = try? String(contentsOf: htmlUrl) else {
        // Fallback: load without embedded markdown (original behavior)
        return (try! String(contentsOf: htmlUrl), baseURL)
    }

    // Escape the markdown for embedding in a JS string literal
    let escapedMarkdown = markdown
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
        .replacingOccurrences(of: "$", with: "\\$")

    let initScript = """
    <script>
    document.addEventListener('DOMContentLoaded', function() {
        window.renderMarkdown({ markdown: `\(escapedMarkdown)`, enableImage: \(enableImage) });
    });
    </script>
    """

    // Insert before </body>
    htmlString = htmlString.replacingOccurrences(of: "</body>", with: "\(initScript)\n</body>")

    return (htmlString, baseURL)
}
```

Modify `configureWebView` to accept optional initial markdown:

```swift
func configureWebView(with renderingConfiguration: MarkdownRenderingConfiguration,
                      styled: Bool,
                      initialMarkdown: String? = nil,
                      enableImage: Bool = true) {
    webView?.removeFromSuperview()
    isWebViewLoaded = false
    pendingRenderRequest = nil

    let configuration = WKWebViewConfiguration()
    configuration.processPool = Self.sharedProcessPool  // from B-1
    let contentController = scriptBuilder.makeContentController(configuration: renderingConfiguration)
    eventBridge?.attach(to: contentController)
    configuration.userContentController = contentController

    webView = webViewFactory.makeWebView(
        with: configuration,
        in: self,
        scrollEnabled: isScrollEnabled,
        navigationDelegate: self
    )

    if let initialMarkdown {
        // B-5: Embed markdown in HTML → single atomic load
        let (htmlString, baseURL) = buildInitialHTML(
            styled: styled,
            markdown: initialMarkdown,
            enableImage: enableImage
        )
        webView?.loadHTMLString(htmlString, baseURL: baseURL)
    } else {
        // Original path: load HTML file, wait for didFinish, then render
        let htmlUrl = styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl
        webView?.load(URLRequest(url: htmlUrl))
    }
}
```

Modify `renderMarkdown` to use the embedded path when WebView is not loaded:

```swift
private func renderMarkdown(markdown: String, enableImage: Bool) {
    guard let webView else { return }

    guard isWebViewLoaded else {
        // Instead of just queuing, check if we should reconfigure with embedded content
        pendingRenderRequest = PendingRenderRequest(markdown: markdown, enableImage: enableImage)
        return
    }

    // ... existing callAsyncJavaScript path (unchanged)
}
```

The key integration point: when `reconfigure()` is called followed immediately by `render()`, the `render()` call currently queues a `pendingRenderRequest` because `isWebViewLoaded` is false. We can optimize the common `init(css:plugins:stylesheets:styled:)` + `render()` path:

```swift
// In render(markdown:options:):
public func render(markdown: String, options: RenderOptions = RenderOptions()) {
    if !isWebViewLoaded, webView != nil {
        // WebView is loading but not ready — we're in the pendingRenderRequest window.
        // Cancel current load and restart with embedded markdown.
        pendingRenderRequest = nil
        // Re-trigger configureWebView with embedded content
        // This requires storing the current configuration — see "State tracking" below.
        if let currentConfig = currentRenderingConfiguration, let currentStyled = currentStyledFlag {
            configureWebView(
                with: currentConfig,
                styled: currentStyled,
                initialMarkdown: markdown,
                enableImage: options.enableImage
            )
            return
        }
    }
    renderMarkdown(markdown: markdown, enableImage: options.enableImage)
}
```

**State tracking additions:**

```swift
// Store current configuration for re-use in the embedded path
private var currentRenderingConfiguration: MarkdownRenderingConfiguration?
private var currentStyledFlag: Bool?

// In configureWebView:
self.currentRenderingConfiguration = renderingConfiguration
self.currentStyledFlag = styled
```

### Simplification: Alternative approach (less invasive)

If the above is too complex, a simpler approach: just embed the markdown in the HTML `DOMContentLoaded` listener during the **initial** `configureWebView` call when it's known at construction time.

Modify the convenience initializer that already has both config and markdown:

```swift
// The deprecated load() method already calls reconfigure + render.
// The MarkdownUI.makeUIView already calls init(css:plugins:...) + render().
// The common pattern is: init → reconfigure → render (in quick succession).
//
// Simplest approach: add an initialMarkdown parameter to the convenience init
// and pass it through to configureWebView.
```

### Risks

- **`loadHTMLString` + `baseURL`:** The `baseURL` must be set to the Resources directory for relative `./main.js` and `./main.css` references to resolve. If `baseURL` is the directory containing `styled.html`, this works correctly.
- **Escaping:** Markdown content may contain backticks, backslashes, or `${}` template literals. The escaping logic must be thorough.
- **Re-render after embed:** After the initial embedded render, subsequent `render()` calls still use `callAsyncJavaScript` (the normal path). The `didFinish` callback must still fire and set `isWebViewLoaded = true`.

### Verification

- Render markdown immediately after init. Measure time-to-first-paint with `CFAbsoluteTimeGetCurrent()` delta.
- Compare against baseline (queue pending + didFinish + callAsyncJavaScript).
- Test: markdown with backticks, backslashes, template literal syntax `${...}`, and multi-line content.
- Test: calling `render()` multiple times in quick succession.

### Estimated diff: ~40-60 lines in `MarkdownView.swift`

---

## B-4: Inline HTML/JS/CSS (Eliminate File I/O)

### Problem

Current loading chain:
1. Swift loads `styled.html` via `URLRequest(url:)` (file I/O)
2. WKWebView parses HTML, finds `<script src="./main.js">` and `<link href="./main.css">`
3. WKWebView makes two more file I/O requests for JS and CSS

Three separate file reads before any rendering can begin.

### Design

Bundle JS and CSS content directly into the HTML string at build time, creating self-contained HTML templates that require zero additional file fetches.

**Two approaches:**

#### Approach A: Build-time inlining (Recommended)

Modify `build.mjs` to produce self-contained HTML files with JS/CSS inlined.

#### Approach B: Runtime inlining (Swift side)

Read JS/CSS files at runtime and inject them into the HTML string. Simpler to implement but adds Swift-side string manipulation overhead.

### Changes (Approach A: Build-time inlining)

**File: `webassets/build.mjs`**

```javascript
import * as esbuild from 'esbuild';
import { readFileSync, writeFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outdir = resolve(__dirname, '../Sources/MarkdownView/Resources');

// Step 1: Build JS and CSS as before
await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  outdir,
  target: ['safari13'],
  legalComments: 'none',
});

// Step 2: Read built artifacts
const mainJs = readFileSync(resolve(outdir, 'main.js'), 'utf-8');
const mainCss = readFileSync(resolve(outdir, 'main.css'), 'utf-8');

// Step 3: Generate self-contained HTML templates
const styledHtml = `<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <style>${mainCss}</style>
        <script>${mainJs}</script>
    </head>
    <body>
        <div class="container markdown-body" id="contents"></div>
    </body>
</html>`;

const nonStyledHtml = `<!doctype html>
<html>
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
        <script>${mainJs}</script>
    </head>
    <body>
        <div class="container markdown-body" id="contents"></div>
    </body>
</html>`;

writeFileSync(resolve(outdir, 'styled.html'), styledHtml);
writeFileSync(resolve(outdir, 'non_styled.html'), nonStyledHtml);
```

**File: `MarkdownView.swift`**

The Swift side changes from file URL loading to `loadHTMLString`:

```swift
// Replace:
//   webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
// With:
private static let styledHtmlString: String = {
    guard let url = styledHtmlUrl,
          let html = try? String(contentsOf: url) else { return "" }
    return html
}()

private static let nonStyledHtmlString: String = {
    guard let url = nonStyledHtmlUrl,
          let html = try? String(contentsOf: url) else { return "" }
    return html
}()

// In configureWebView:
let htmlString = styled ? Self.styledHtmlString : Self.nonStyledHtmlString
webView?.loadHTMLString(htmlString, baseURL: nil)
// baseURL: nil is fine because all resources are now inlined
```

**File: `Package.swift`**

Since JS and CSS are now inlined in the HTML files, we can remove standalone `main.js` and `main.css` from resources — but keep them for tests and for the non-inlined fallback:

```swift
// Keep all 4 resources for now (tests reference main.js directly)
resources: [
    .copy("Resources/styled.html"),
    .copy("Resources/non_styled.html"),
    .copy("Resources/main.js"),   // Still needed for Playwright tests
    .copy("Resources/main.css")   // Still needed for Playwright tests
]
```

### Interaction with B-5

When B-4 and B-5 are both applied:
- B-4 eliminates the external `<script src>` / `<link href>` fetches (all inlined)
- B-5 embeds the initial markdown in the same HTML string
- Combined: a single `loadHTMLString` call provides everything — HTML structure, CSS, JS library, and initial content. Zero additional fetches.

The `buildInitialHTML` method from B-5 should operate on the pre-cached `styledHtmlString` / `nonStyledHtmlString` (which already contain inlined JS/CSS), inserting only the initial markdown `<script>` block.

### Risks

- **HTML file size:** `styled.html` grows from 260 bytes to ~736KB (715KB JS + 21KB CSS). This is loaded as an in-memory string, not a file fetch, so WKWebView processes it faster than three separate file loads.
- **`baseURL: nil`:** With all resources inlined, no relative URLs need resolving. If user-injected CSS references relative URLs (e.g., `url(./font.woff)`), those would break. However, current MarkdownScriptBuilder only injects inline CSS text and absolute stylesheet URLs, so this is safe.
- **Static `let` caching:** HTML strings are read once at first access and cached in static memory (~736KB × 2 = ~1.4MB). Acceptable trade-off for eliminating repeated file I/O.
- **Playwright tests:** Tests reference `main.js` directly via file path. Keep standalone `main.js` in the build output alongside the inlined HTML. Tests remain unchanged.

### Verification

- Build with updated `build.mjs`. Verify `styled.html` contains inlined `<style>` and `<script>`.
- Render markdown in the app. Verify identical visual output.
- Run Playwright tests (`npm test`). All 16 tests should pass.
- Profile with Instruments: compare file I/O activity before vs after.

### Estimated diff: ~30 lines in `build.mjs`, ~20 lines in `MarkdownView.swift`

---

## B-3: JS Bundle Optimization (highlight.js Lazy Loading)

### Problem

`main.js` is ~715KB minified. Of this, the vast majority is highlight.js language definitions (113 languages × ~3-8KB each). Most users only need 10-15 common languages. The entire bundle must be parsed and executed before `window.renderMarkdown` becomes available.

### Design

Split highlight.js into two tiers:
1. **Core bundle** (~150-200KB): markdown-it + emoji + hljs core + 15 common languages
2. **Extended languages** (~500KB): remaining 98 languages, loaded on demand

The core bundle provides instant rendering. Extended languages load asynchronously and apply retroactively to already-rendered code blocks.

### Tier 1 Languages (15 common)

Selected based on GitHub language statistics and typical Markdown usage:

```
javascript, typescript, python, java, swift, kotlin,
c, cpp, csharp, go, rust, ruby,
bash, json, xml (includes html)
```

### Changes

**File: `webassets/src/js/index.js`** → Split into modules:

```
webassets/src/js/
├── index.js              # Entry point: imports core + schedules lazy load
├── hljs-core-langs.js    # Tier 1: 15 language imports + registrations
├── hljs-extended-langs.js # Tier 2: 98 language imports + registrations
└── render.js             # renderMarkdown, usePlugin, postDocumentHeight (extracted)
```

**File: `webassets/src/js/hljs-core-langs.js`**

```javascript
import hljs from "highlight.js/lib/core";
import javascript from "highlight.js/lib/languages/javascript";
import typescript from "highlight.js/lib/languages/typescript";
import python from "highlight.js/lib/languages/python";
import java from "highlight.js/lib/languages/java";
import swift from "highlight.js/lib/languages/swift";
import kotlin from "highlight.js/lib/languages/kotlin";
import c from "highlight.js/lib/languages/c";
import cpp from "highlight.js/lib/languages/cpp";
import csharp from "highlight.js/lib/languages/csharp";
import go from "highlight.js/lib/languages/go";
import rust from "highlight.js/lib/languages/rust";
import ruby from "highlight.js/lib/languages/ruby";
import bash from "highlight.js/lib/languages/bash";
import json from "highlight.js/lib/languages/json";
import xml from "highlight.js/lib/languages/xml";

hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('typescript', typescript);
hljs.registerLanguage('python', python);
hljs.registerLanguage('java', java);
hljs.registerLanguage('swift', swift);
hljs.registerLanguage('kotlin', kotlin);
hljs.registerLanguage('c', c);
hljs.registerLanguage('cpp', cpp);
hljs.registerLanguage('csharp', csharp);
hljs.registerLanguage('go', go);
hljs.registerLanguage('rust', rust);
hljs.registerLanguage('ruby', ruby);
hljs.registerLanguage('bash', bash);
hljs.registerLanguage('json', json);
hljs.registerLanguage('xml', xml);

export default hljs;
```

**File: `webassets/src/js/hljs-extended-langs.js`**

```javascript
// All 98 remaining languages
import hljs from "highlight.js/lib/core";
import ada from "highlight.js/lib/languages/ada";
// ... (remaining 97 imports)
// ... (remaining 97 registerLanguage calls)

export function rehighlightAll() {
    document.querySelectorAll('pre code').forEach((block) => {
        // Only re-highlight blocks that hljs couldn't identify with core languages
        if (block.classList.contains('hljs') && block.dataset.highlighted !== 'yes') {
            hljs.highlightElement(block);
        }
    });
}
```

**File: `webassets/src/js/index.js`** (rewritten)

```javascript
import hljs from "./hljs-core-langs.js";
import MarkdownIt from "markdown-it";
import { full as emoji } from "markdown-it-emoji";
import "./../css/bootstrap.css";
import "./../css/gist.css";
import "./../css/github.css";
import "./../css/index.css";

// ... (renderMarkdown, usePlugin, postDocumentHeight — same logic as current)

// Lazy-load extended languages after initial render
let extendedLoaded = false;
const loadExtendedLanguages = () => {
    if (extendedLoaded) return;
    extendedLoaded = true;
    import("./hljs-extended-langs.js").then(({ rehighlightAll }) => {
        rehighlightAll();
    });
};

// Original renderMarkdown — add lazy load trigger at the end
const originalRenderMarkdown = window.renderMarkdown;
window.renderMarkdown = (payload) => {
    originalRenderMarkdown(payload);
    // Trigger extended language load after first render
    loadExtendedLanguages();
};
```

**File: `webassets/build.mjs`**

```javascript
import * as esbuild from 'esbuild';

await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  splitting: true,        // Enable code splitting for dynamic import()
  format: 'esm',          // Required for splitting
  outdir: '../Sources/MarkdownView/Resources',
  target: ['safari13'],
  legalComments: 'none',
});
```

### Important: `format: 'esm'` consideration

esbuild code splitting requires `format: 'esm'`. But WKWebView's `loadHTMLString` doesn't support ES modules (`<script type="module">`) well with `baseURL: nil`.

**Resolution options:**

1. **Keep IIFE format, concatenate at build time:** Don't use dynamic `import()`. Instead, produce two separate IIFE bundles (core, extended) and provide a Swift-side mechanism to inject the extended bundle as a `WKUserScript` after initial load.

2. **Use `baseURL` pointing to bundle resources:** Keep file-based loading for the extended chunk (it's loaded async after first render, so file I/O cost is acceptable). Use `baseURL` that resolves to the Resources directory.

3. **Build two complete standalone bundles:** `main-core.js` (core only, ~150KB) and `main-full.js` (all 113, ~715KB). Load `main-core.js` first; after first render, inject `main-full.js` as a WKUserScript and re-highlight.

**Recommended: Option 3** — simplest, no format changes needed, and the full bundle is a lazy upgrade.

### Changes (Option 3: Dual bundle)

**File: `webassets/build.mjs`**

```javascript
import * as esbuild from 'esbuild';

// Core bundle (~150-200KB): 15 common languages
await esbuild.build({
  entryPoints: { 'main-core': './src/js/index-core.js' },
  bundle: true,
  minify: true,
  outdir: '../Sources/MarkdownView/Resources',
  target: ['safari13'],
  legalComments: 'none',
});

// Full bundle (~715KB): all 113 languages (backward compatible)
await esbuild.build({
  entryPoints: { main: './src/js/index.js' },
  bundle: true,
  minify: true,
  outdir: '../Sources/MarkdownView/Resources',
  target: ['safari13'],
  legalComments: 'none',
});
```

**File: `webassets/src/js/index-core.js`**

Same as current `index.js` but with only 15 language imports.

**File: `MarkdownView.swift`** (Swift-side lazy loading)

```swift
private var hasInjectedExtendedLanguages = false

private func injectExtendedLanguagesIfNeeded() {
    guard !hasInjectedExtendedLanguages, let webView else { return }
    hasInjectedExtendedLanguages = true

    // Load the full bundle (which re-registers all languages) and re-highlight
    guard let fullJsUrl = Bundle.module.url(forResource: "main", withExtension: "js"),
          let fullJs = try? String(contentsOf: fullJsUrl) else { return }

    // Inject as user script + trigger re-highlight
    let rehighlightScript = fullJs + """
    ; document.querySelectorAll('pre code.hljs').forEach(function(block) {
        block.removeAttribute('data-highlighted');
        hljs.highlightElement(block);
    });
    """

    webView.evaluateJavaScript(rehighlightScript) { _, error in
        if let error {
            print("[MarkdownView] Extended languages injection failed: \\(error)")
        }
    }
}
```

Call `injectExtendedLanguagesIfNeeded()` in `didFinish` or after the first `renderMarkdown` completes.

### Bundle size estimate

| Bundle | Content | Estimated size |
|--------|---------|---------------|
| `main-core.js` | markdown-it (~100KB) + hljs core (~30KB) + 15 langs (~30KB) + emoji (~15KB) | ~175KB |
| `main.js` | Full current bundle | ~715KB |
| Reduction in initial parse | 715KB → 175KB | **~75% smaller** |

### Risks

- **Language mismatch window:** Between initial render (core only) and extended injection, code blocks in uncommon languages (e.g., Haskell, Erlang) won't be highlighted. They'll render as plain `<code>` blocks, then re-highlight once the full bundle loads. This is a brief visual flash.
- **Re-highlight flash:** When extended languages are injected, `hljs.highlightElement` re-processes code blocks, potentially causing a visible re-paint. Use `requestAnimationFrame` to batch this.
- **Full bundle is still in the app bundle:** Both `main-core.js` and `main.js` ship in the SPM package. Total JS size increases to ~890KB in the app bundle (though only ~175KB is parsed upfront).
- **Test coverage:** Playwright tests use `main.js` (full bundle). Add tests for `main-core.js` that verify core languages highlight correctly and uncommon languages degrade gracefully.

### Verification

- Build both bundles. Compare sizes.
- Load with `main-core.js`: verify JavaScript, Python, Swift, etc. highlight correctly.
- Load with `main-core.js`: verify Haskell code block renders as plain text (no error).
- Inject `main.js` after render: verify Haskell code block re-highlights.
- Profile JS parse time with `performance.now()` in both bundles.
- Run Playwright tests: all 16 pass with full bundle; add 2+ tests for core-only bundle.

### Estimated diff: ~50 lines new JS files, ~30 lines `build.mjs`, ~30 lines `MarkdownView.swift`

---

## B-2: WebView Pre-warming (Pooling)

### Problem

`WKWebView` initialization blocks the main thread for 50-100+ ms. First page load adds another 200-400 ms. In a List or LazyVStack with many cells, each cell pays this cost on appearance.

### Design

Maintain a pool of pre-warmed `WKWebView` instances that have already loaded the HTML template. When `reconfigure()` is called, dequeue a warm instance instead of creating from scratch.

### Architecture

```swift
/// Manages a pool of pre-loaded WKWebView instances ready for immediate use.
final class MarkdownWebViewPool {
    static let shared = MarkdownWebViewPool()

    private var styledPool: [WKWebView] = []
    private var nonStyledPool: [WKWebView] = []
    private let maxPoolSize = 3
    private let lock = NSLock()

    /// Pre-warm the pool. Call from AppDelegate or early in the app lifecycle.
    func warmUp(count: Int = 2, styled: Bool = true) { ... }

    /// Dequeue a pre-warmed WebView, or return nil if pool is empty.
    func dequeue(styled: Bool) -> WKWebView? { ... }

    /// Return a WebView to the pool for reuse (optional).
    func recycle(_ webView: WKWebView, styled: Bool) { ... }
}
```

### Key Design Decisions

1. **Shared vs per-configuration pools:** Pre-warmed WebViews use a **default configuration** (no custom CSS/plugins). When dequeued, CSS/plugins are injected via `evaluateJavaScript` post-load rather than `WKUserScript`. This allows pooling without needing separate pools per configuration.

2. **Pool size:** Default max 3 per style (styled/non-styled). Configurable. Each pre-warmed instance uses ~100-200MB after HTML load, so the pool trades memory for latency.

3. **Thread safety:** Pool access is guarded by `NSLock`. WebView creation happens on the main thread (UIKit requirement).

4. **Refill strategy:** After a dequeue, enqueue a background task to create a replacement. The pool stays warm.

### Changes

**New file: `MarkdownWebViewPool.swift`**

```swift
import UIKit
import WebKit

public final class MarkdownWebViewPool {
    public static let shared = MarkdownWebViewPool()

    private var styledPool: [(webView: WKWebView, isLoaded: Bool)] = []
    private var nonStyledPool: [(webView: WKWebView, isLoaded: Bool)] = []
    private let maxPoolSize: Int
    private let lock = NSLock()
    private let processPool = MarkdownView.sharedProcessPool  // Reuse from B-1

    public init(maxPoolSize: Int = 3) {
        self.maxPoolSize = maxPoolSize
    }

    /// Pre-warm pool entries. Call early (e.g., in AppDelegate.didFinishLaunching).
    public func warmUp(count: Int = 2, styled: Bool = true) {
        guard count > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for _ in 0..<min(count, self.maxPoolSize) {
                self.createAndEnpool(styled: styled)
            }
        }
    }

    /// Dequeue a pre-warmed WebView. Returns nil if pool is empty.
    func dequeue(styled: Bool) -> WKWebView? {
        lock.lock()
        defer { lock.unlock() }

        let pool = styled ? styledPool : nonStyledPool
        guard let index = pool.firstIndex(where: { $0.isLoaded }) else { return nil }

        let entry = pool[index]
        if styled {
            styledPool.remove(at: index)
        } else {
            nonStyledPool.remove(at: index)
        }

        // Schedule refill
        DispatchQueue.main.async { [weak self] in
            self?.createAndEnpool(styled: styled)
        }

        return entry.webView
    }

    private func createAndEnpool(styled: Bool) {
        lock.lock()
        let currentCount = styled ? styledPool.count : nonStyledPool.count
        guard currentCount < maxPoolSize else {
            lock.unlock()
            return
        }
        lock.unlock()

        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        // Default userContentController (no custom CSS/plugins)
        // CSS/plugins will be injected via evaluateJavaScript after dequeue

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Load HTML template
        let htmlUrl = styled ? MarkdownView.styledHtmlUrl : MarkdownView.nonStyledHtmlUrl

        // Use loadHTMLString if B-4 is applied, otherwise file URL
        let htmlString = styled ? MarkdownView.styledHtmlString : MarkdownView.nonStyledHtmlString
        webView.loadHTMLString(htmlString, baseURL: nil)

        // Track load completion via navigation delegate or a helper
        let tracker = PoolLoadTracker { [weak self] in
            self?.lock.lock()
            if styled {
                if let idx = self?.styledPool.firstIndex(where: { $0.webView === webView }) {
                    self?.styledPool[idx].isLoaded = true
                }
            } else {
                if let idx = self?.nonStyledPool.firstIndex(where: { $0.webView === webView }) {
                    self?.nonStyledPool[idx].isLoaded = true
                }
            }
            self?.lock.unlock()
        }
        webView.navigationDelegate = tracker
        // Retain tracker
        objc_setAssociatedObject(webView, &PoolLoadTracker.key, tracker, .OBJC_ASSOCIATION_RETAIN)

        lock.lock()
        if styled {
            styledPool.append((webView, false))
        } else {
            nonStyledPool.append((webView, false))
        }
        lock.unlock()
    }
}

private class PoolLoadTracker: NSObject, WKNavigationDelegate {
    static var key: UInt8 = 0
    let onLoaded: () -> Void

    init(onLoaded: @escaping () -> Void) {
        self.onLoaded = onLoaded
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoaded()
    }
}
```

**File: `MarkdownView.swift`** — integrate pool

```swift
// In configureWebView, before creating a new WKWebView:
if let pooledWebView = MarkdownWebViewPool.shared.dequeue(styled: styled) {
    // Pooled WebView: already loaded HTML, just needs CSS/plugin injection
    webView = pooledWebView
    webView?.translatesAutoresizingMaskIntoConstraints = false
    webView?.navigationDelegate = self
    webView?.scrollView.isScrollEnabled = isScrollEnabled
    addSubview(webView!)
    // Add Auto Layout constraints
    NSLayoutConstraint.activate([
        webView!.topAnchor.constraint(equalTo: topAnchor),
        webView!.bottomAnchor.constraint(equalTo: bottomAnchor),
        webView!.leadingAnchor.constraint(equalTo: leadingAnchor),
        webView!.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])

    // Inject CSS/plugins via evaluateJavaScript (since WKUserScripts are per-configuration)
    injectUserScriptsPostLoad(configuration: renderingConfiguration)
    // Attach event bridge to existing contentController
    eventBridge?.attach(to: pooledWebView.configuration.userContentController)

    isWebViewLoaded = true  // Already loaded
    return
} else {
    // No pooled instance available — fall through to normal creation
}
```

### Exposing internals for the pool

B-1 introduced `private static let sharedProcessPool`. The pool needs access to this. Change to `internal static`:

```swift
// MarkdownView.swift
static let sharedProcessPool = WKProcessPool()  // Remove 'private'
```

Similarly, HTML URL statics need `internal` access:

```swift
static var styledHtmlUrl: URL = { ... }()     // internal (remove private extension)
static var nonStyledHtmlUrl: URL = { ... }()   // internal (remove private extension)
```

### Post-load CSS/plugin injection

Since pooled WebViews have a **default** `WKUserContentController`, CSS and plugins must be injected via `evaluateJavaScript` rather than `WKUserScript`:

```swift
private func injectUserScriptsPostLoad(configuration: MarkdownRenderingConfiguration) {
    guard let webView else { return }

    let scripts = scriptBuilder.makeScriptStrings(configuration: configuration)
    for script in scripts {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                print("[MarkdownView] Script injection failed: \(error)")
            }
        }
    }
}
```

This requires refactoring `MarkdownScriptBuilder` to expose the script strings directly (currently it only creates `WKUserScript` objects wrapped in a `WKUserContentController`):

```swift
// MarkdownScriptBuilder.swift — add:
func makeScriptStrings(configuration: MarkdownRenderingConfiguration) -> [String] {
    var scripts: [String] = []

    if let css = configuration.css {
        scripts.append(styleScript(css))
    }

    configuration.plugins?.forEach { plugin in
        scripts.append(usePluginScript(plugin))
    }

    configuration.stylesheets?.forEach { url in
        scripts.append(linkScript(url))
    }

    return scripts
}
```

### Risks

1. **Memory pressure:** Each pre-warmed WebView consumes 100-200MB. A pool of 3 uses 300-600MB. On memory-constrained devices, this may trigger jetsam. **Mitigation:** Listen for `UIApplication.didReceiveMemoryWarningNotification` and drain the pool.

2. **Pool coherence:** If a dequeued WebView's configuration (user agent, preferences) differs from what's needed, behavior may diverge. **Mitigation:** Use identical base configurations for all pooled instances. Only CSS/plugin customization varies, and that's injected post-dequeue.

3. **Navigation delegate transfer:** The pooled WebView's `navigationDelegate` is initially the `PoolLoadTracker`. It must be reassigned to `MarkdownView` on dequeue. If reassignment races with an in-progress navigation, `didFinish` may be missed. **Mitigation:** Only dequeue from `isLoaded == true` entries.

4. **`eventBridge` attachment:** `MarkdownEventBridge.attach(to:)` calls `userContentController.add(self, name: "updateHeight")`. If called multiple times on the same controller, it may accumulate handlers. **Mitigation:** Remove existing handler before attaching: `userContentController.removeScriptMessageHandler(forName: "updateHeight")`.

5. **Public API implications:** `MarkdownWebViewPool.warmUp()` is a new public API that users must call for the optimization to take effect. This is opt-in — no change for users who don't call it.

### Verification

- Call `MarkdownWebViewPool.shared.warmUp(count: 2)` in `AppDelegate`.
- Create a `MarkdownView` — verify it dequeues from pool (zero WKWebView init time).
- Profile: compare `reconfigure()` time with and without pool (expect 50-100 ms improvement).
- Test: rapid `reconfigure()` calls exhaust pool, then fall back to normal creation.
- Test: memory warning → pool drains → subsequent dequeue returns nil → normal creation.
- Test: CSS/plugin injection on pooled instances works correctly.

### Estimated diff: ~150 lines new file, ~40 lines `MarkdownView.swift`, ~15 lines `MarkdownScriptBuilder.swift`

---

## Implementation Order and Dependencies

```
B-1: Shared ProcessPool          ← standalone, no dependencies
 │
 ├─ B-5: Embed Initial Markdown  ← depends on B-1 (uses sharedProcessPool)
 │   │
 │   └─ B-4: Inline HTML/JS/CSS  ← depends on B-5 (extends buildInitialHTML)
 │       │
 │       └─ B-3: JS Bundle Split ← depends on B-4 (build.mjs changes)
 │
 └─ B-2: WebView Pooling         ← depends on B-1 (sharedProcessPool)
                                    depends on B-4 (loadHTMLString path)
                                    depends on B-1 access modifiers
```

### Commit Plan

Each optimization is a single, independently reviewable commit:

| Order | ID | Commit | Files Changed |
|-------|-----|--------|--------------|
| 1 | B-1 | `perf: share WKProcessPool across MarkdownView instances` | `MarkdownView.swift` |
| 2 | B-5 | `perf: embed initial markdown in HTML to eliminate async round-trip` | `MarkdownView.swift` |
| 3 | B-4 | `perf: inline JS/CSS into HTML templates at build time` | `build.mjs`, `MarkdownView.swift` |
| 4 | B-3 | `perf: split highlight.js into core (15 langs) and extended bundles` | `webassets/src/js/*`, `build.mjs`, `MarkdownView.swift`, `Package.swift` |
| 5 | B-2 | `perf: add WKWebView pre-warming pool for List scenarios` | New `MarkdownWebViewPool.swift`, `MarkdownView.swift`, `MarkdownScriptBuilder.swift`, `MarkdownWebViewFactory.swift` |

### Expected Cumulative Impact

| After | Initial Parse | First Render | Memory (per additional instance) |
|-------|--------------|--------------|----------------------------------|
| Baseline | ~715KB JS | ~250-500ms | 100-200MB |
| + B-1 | ~715KB JS | ~250-500ms | Shared (100-200MB total) |
| + B-5 | ~715KB JS | ~200-400ms (−1 round-trip) | Shared |
| + B-4 | ~715KB JS | ~150-350ms (−file I/O) | Shared |
| + B-3 | ~175KB JS | ~100-250ms (−75% parse) | Shared |
| + B-2 (warm) | 0 (pre-parsed) | ~50-100ms (JS exec only) | Shared (pool pre-allocated) |

---

## Test Strategy

### Existing Tests

- **Playwright (webassets):** 16 functional tests. Must pass after every change. B-3 and B-4 modify the build pipeline — run after each.
- **ExampleSnapshotTests:** Visual regression. Run after B-4 (HTML structure change) and B-3 (highlighting behavior change).

### New Tests Needed

| Change | Test |
|--------|------|
| B-1 | Manual: Instruments memory comparison with multiple instances |
| B-5 | Unit test: `buildInitialHTML` correctly escapes backticks, backslashes, `${}`, newlines |
| B-5 | Integration: render with embedded markdown matches render with callAsyncJavaScript |
| B-4 | Verify `styled.html` contains `<style>` and `<script>` tags (not `<link>` / `<script src>`) |
| B-3 | Playwright: core bundle highlights JS/Python/Swift correctly |
| B-3 | Playwright: core bundle renders Haskell as plain text (no error) |
| B-3 | Playwright: full bundle re-highlights Haskell after injection |
| B-2 | Unit test: pool dequeue returns a loaded WebView |
| B-2 | Unit test: pool exhaustion falls back to normal creation |
| B-2 | Unit test: memory warning drains pool |
| B-2 | Integration: pooled WebView renders markdown identically to non-pooled |

### Performance Benchmarks

Add a benchmark helper (for manual profiling, not CI):

```swift
func measureRenderTime(markdown: String) {
    let start = CFAbsoluteTimeGetCurrent()
    let view = MarkdownView(css: nil, plugins: nil, styled: true)
    view.onRendered = { _ in
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("[Benchmark] Time to first render: \(elapsed * 1000)ms")
    }
    view.render(markdown: markdown)
}
```
