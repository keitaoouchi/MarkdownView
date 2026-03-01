# MarkdownView Performance Improvement Options

## Current Bottleneck Analysis

| Bottleneck | Location | Impact |
|---|---|---|
| **WKWebView creation cost** | `reconfigure()` → new WKWebView | Slow initial display; significant in List with multiple cells |
| **HTML/JS/CSS file loading** | `webView.load(URLRequest(url:))` | `render()` queued until page load completes |
| **JS bundle size** | `main.js` ~715KB (markdown-it + hljs 113 languages) | Parsing/execution takes time |
| **IPC overhead** | Swift → JS (`callAsyncJavaScript`) → Swift (messageHandler) | Async round-trip latency |
| **Height measurement → layout** | DOM measure → postMessage → invalidateIntrinsicContentSize | Frequent layout recalculation in List |

## Options

### A. Pure Swift (Remove WKWebView entirely)

**Approach:** Parse with cmark-gfm (C) or swift-markdown (Apple) → Render with NSAttributedString / SwiftUI Text

**Pros:**
- Eliminates WKWebView startup cost (biggest bottleneck)
- Zero IPC — synchronous rendering possible
- Height measurement via `sizeThatFits` (no async round-trip)
- Significant memory reduction (no WebContent process)
- Optimal for large numbers of cells in List/LazyVStack

**Lost capabilities:**
- **highlight.js 113-language syntax highlighting** — No equivalent exists in native Swift
- **markdown-it plugin ecosystem** — Footnotes, math (KaTeX), sub/sup, etc.
- **CSS-based styling freedom** — Custom CSS / external stylesheet injection impossible
- **HTML passthrough** (`html: true`) — Rendering raw HTML embedded in Markdown becomes difficult
- **Bootstrap-based rich table display**

**Assessment:** Feature regression is **severe**. The 113-language highlight.js support and plugin system are key differentiators. However, viable as a **separate lightweight target** (`MarkdownViewLite`).

---

### B. WKWebView Deep Optimization (Improve current architecture)

Maintain WKWebView-based architecture while systematically addressing known bottlenecks.

#### B-1. Shared WKProcessPool + Configuration Reuse

Share a static `WKProcessPool` across all instances to reduce WebContent process startup cost.

- **Impact:** Reduces WKWebView creation overhead when using multiple instances
- **Implementation cost:** Low (few lines of code)

#### B-2. WKWebView Pre-warming (Pooling)

Pre-create WebViews and maintain a pool for instant dequeue.

- **Impact:** Eliminates WebView creation wait time; most effective for List scenarios
- **Implementation cost:** Medium (pool management, pre-loaded HTML, configuration handling)

#### B-3. JS Bundle Optimization

Current `main.js` is ~715KB with significant optimization potential.

- **Lazy-load highlight.js languages:** Bundle only 10-15 common languages initially; load rest on demand
- **Code splitting:** Use esbuild splitting for lighter initial load
- **Optional highlight.js:** Provide a lightweight build for use cases without syntax highlighting

- **Impact:** Reduce initial JS parse/execution time; potentially under 200KB
- **Implementation cost:** Medium (esbuild config changes + lazy-load mechanism)

#### B-4. Inline HTML/JS/CSS (Eliminate file I/O)

Embed JS/CSS directly into HTML string and use `loadHTMLString()` instead of file-based loading.

- **Impact:** Eliminates file I/O
- **Implementation cost:** Low-Medium

#### B-5. Eliminate Initial Render Wait (Embed Markdown in Initial Load)

Embed the initial markdown content directly in the HTML template to avoid the two-step process (load HTML → didFinish → render markdown).

- **Impact:** Removes one async round-trip from initial display
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

**Assessment:** Theoretically attractive but **visual consistency risk** is the biggest concern.

---

### D. WKWebView + Offscreen Rendering (Snapshot)

**Approach:** Render in WKWebView, capture result as UIImage/CALayer, release WebView.

**Assessment:** Too limited. Loss of interactivity (link taps, etc.) is fatal for most use cases.

---

## Recommended: Incremental Approach

Maintain current architecture and stack improvements in order of effort-to-impact ratio:

| Priority | Measure | Effect | Cost |
|---|---|---|---|
| **1** | B-1: Shared ProcessPool | Reduce WKWebView startup cost | Low |
| **2** | B-5: Embed initial markdown in HTML load | Reduce first-render latency | Low |
| **3** | B-4: Inline HTML/JS/CSS | Eliminate file I/O | Low-Medium |
| **4** | B-3: JS bundle optimization (hljs lazy-load) | Reduce JS parse time | Medium |
| **5** | B-2: WebView pooling | Improve mass-use in List | Medium |

Pure Swift (A) is viable only as a **separate package** (`MarkdownViewLite`), not a replacement.

Hybrid (C) has high maintenance cost that likely doesn't justify the visual consistency challenges.
