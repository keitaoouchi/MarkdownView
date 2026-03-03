# List Performance Optimization — Design Document

This document provides investigation results, design options, and implementation specs for optimizing MarkdownView in SwiftUI `List` / UIKit `UITableView` scenarios with many cells.

## Current State (Post B-Series)

### What B-2 through B-4 achieved

| Optimization | Effect | List Impact |
|---|---|---|
| B-4: Inlined JS/CSS in HTML | Eliminates file I/O on each load | Every cell benefits |
| B-3: Core/Full JS split | Core bundle 297KB (vs 733KB full) | Faster initial parse per cell |
| B-2: WebView pre-warming pool | Pre-loaded WebViews ready to dequeue | First 1-3 cells only |

### Remaining bottlenecks in List(80 cells)

| Bottleneck | Per-cell Cost | Impact at Scale |
|---|---|---|
| **WKWebView creation** | ~50-100 ms (init + config) | 80 cells × 75ms = 6 seconds total |
| **HTML parse (319KB inlined template)** | ~100-200 ms | Dominates cold start per cell |
| **JS execution (renderMarkdown)** | ~10-50 ms | Acceptable individually, adds up |
| **No view recycling** | Each `makeUIView` creates new WKWebView | Memory: 80 × WKWebView in worst case |
| **No height caching** | Every cell re-renders and re-measures | Duplicate work on scroll back |
| **No rendered HTML caching** | Same markdown re-parsed by JS on reappear | Redundant computation |

### Key insight

The current pool (B-2) creates new WebViews proactively, but **never reclaims** them when cells scroll off-screen. In a List of 80 rows, this means up to 80 WKWebViews alive simultaneously. The core problem is a **one-way lifecycle**: create → use → abandon.

---

## Data Flow Trace (Current List Scenario)

```
SwiftUI List renders row N
  → MarkdownUI.makeUIView()
    → MarkdownView(css:plugins:stylesheets:styled:)
      → reconfigure() → configureWebView()
        → MarkdownWebViewPool.shared.dequeue()   // usually nil (pool empty)
        → WKWebView(frame:configuration:)         // ~50-100 ms
        → loadHTMLString(319KB, baseURL: nil)      // async, ~100-200 ms
  → MarkdownUI.updateUIView()
    → render(markdown:) → pendingRenderRequest queued
      → [didFinish] → callAsyncJavaScript          // ~10-50 ms
        → JS renders → height posted → onRendered
          → @State contentHeight updated → frame(height:) → layout

Row N scrolls off-screen:
  → SwiftUI may discard the UIView
  → WKWebView is deallocated (no recycling)

Row N scrolls back on-screen:
  → Entire cycle repeats from scratch
```

---

## Optimization Strategies

### C-1: WebView Recycling (Reuse Pool)

**Problem:** Each cell creates and destroys a WKWebView. No recycling.

**Design:** Transform the current one-way pool into a bidirectional recycle pool. When a MarkdownView is removed from the view hierarchy, its WKWebView is returned to the pool (cleaned up) instead of being deallocated.

```
Pool (pre-warmed)
  ┌─────────┐     dequeue()      ┌──────────────┐
  │ Ready    │ ──────────────────→│ MarkdownView │
  │ WebViews │                    │ (in cell)    │
  │          │ ←──────────────────│              │
  └─────────┘     enqueue()      └──────────────┘
                (on disappear)
```

**Key changes:**

1. **`MarkdownWebViewPool`** — Add `enqueue(webView:styled:)` method that resets state and returns the WebView to the pool:

```swift
func enqueue(_ webView: WKWebView, styled: Bool) {
    // Reset content: load blank or base HTML template
    webView.loadHTMLString(baseHtml(styled: styled), baseURL: nil)
    // Remove message handlers to avoid leaks
    // Re-add to pool
    lock.lock()
    // ... append to styledPool or nonStyledPool
    lock.unlock()
}
```

2. **`MarkdownView`** — Return WebView to pool when removed from hierarchy:

```swift
open override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil, let wv = webView {
        // Detach and return to pool
        MarkdownWebViewPool.shared.enqueue(wv, styled: currentStyledFlag)
        wv.removeFromSuperview()
        webView = nil
        isWebViewLoaded = false
    }
}
```

3. **`MarkdownUI`** — Leverage `dismantleUIView` or `updateUIView` visibility tracking.

**Estimated impact:** Eliminates WKWebView creation cost for recycled cells. After initial burst, all cells reuse existing WebViews.

**Risks:**
- WKWebView state leakage between cells (stale content flash). Mitigate: load base HTML on enqueue, show content only after new render completes.
- `willMove(toWindow:)` timing may not align perfectly with SwiftUI List cell lifecycle. Need empirical testing.
- Recycled WebView's `userContentController` may need cleanup/reattach of message handlers.

**Complexity:** Medium. Touches MarkdownView lifecycle, pool, and MarkdownUI.

---

### C-2: Height Cache

**Problem:** When a cell scrolls back into view, the markdown is re-rendered just to get the same height. Layout flickers because `contentHeight` starts at 1, then jumps to the real value.

**Design:** Cache markdown → height mappings. On `makeUIView`/`updateUIView`, check cache first for immediate frame sizing.

```swift
public final class MarkdownHeightCache: @unchecked Sendable {
    static let shared = MarkdownHeightCache()

    private var cache: [String: CGFloat] = [:]  // key: hash of (markdown + width + styled)
    private let lock = NSLock()

    func height(for markdown: String, width: CGFloat, styled: Bool) -> CGFloat? { ... }
    func store(height: CGFloat, for markdown: String, width: CGFloat, styled: Bool) { ... }
}
```

**Integration with MarkdownUI:**

```swift
// In MarkdownListRow:
MarkdownUI(body: item.markdown)
    .onRendered { height in
        contentHeight = height
        MarkdownHeightCache.shared.store(height: height, for: item.markdown, width: proxy.size.width, styled: true)
    }
    .frame(height: MarkdownHeightCache.shared.height(for: item.markdown, width: 402, styled: true) ?? 1)
```

Or, integrate into `MarkdownView` itself so it's automatic:

```swift
// In MarkdownView, after receiving height from JS:
private func handleHeightUpdate(_ height: CGFloat) {
    MarkdownHeightCache.shared.store(height: height, for: currentMarkdown, width: bounds.width, styled: ...)
    intrinsicContentHeight = height
    onRendered?(height)
}

// In configureWebView or render, check cache for immediate intrinsicContentSize:
if let cached = MarkdownHeightCache.shared.height(for: markdown, width: bounds.width, styled: styled) {
    intrinsicContentHeight = cached
}
```

**Estimated impact:** Eliminates layout jump on scroll-back. Cells appear with correct height immediately.

**Risks:**
- Cache invalidation: width changes (rotation), dynamic type changes, CSS changes.
- Memory: for 80 items this is negligible. For unbounded lists, consider LRU eviction.

**Complexity:** Low. Self-contained addition.

---

### C-3: Rendered HTML Cache

**Problem:** When a cell scrolls back and gets a recycled WebView (C-1), the markdown is re-parsed by JS even though the output is identical.

**Design:** Cache the rendered HTML output from JS. On re-render, inject the cached HTML directly into the DOM (bypassing markdown-it parsing).

**JS-side:**

```javascript
// In window.renderMarkdown:
// After md.render(markdown), also expose window.setRenderedHTML(html)
window.setRenderedHTML = function(html, enableImage) {
    document.getElementById('contents').innerHTML = html;
    if (!enableImage) { /* remove img tags */ }
    hljs.highlightAll();
    postDocumentHeight();
};
```

**Swift-side:**

```swift
final class MarkdownHTMLCache {
    static let shared = MarkdownHTMLCache()
    private var cache: [String: String] = [:]  // markdown hash → rendered HTML

    func renderedHTML(for markdown: String) -> String? { ... }
    func store(html: String, for markdown: String) { ... }
}
```

When rendering, check cache first:

```swift
if let cachedHTML = MarkdownHTMLCache.shared.renderedHTML(for: markdown) {
    webView?.callAsyncJavaScript("window.setRenderedHTML(html)", arguments: ["html": cachedHTML], ...)
} else {
    webView?.callAsyncJavaScript("window.renderMarkdown(payload)", arguments: ["payload": payload], ...)
}
```

**Estimated impact:** Eliminates JS parsing cost (~10-50 ms) on scroll-back. Combined with C-1 (recycling), a returning cell can display content almost instantly.

**Risks:**
- Cache size: rendered HTML can be large. LRU with a byte-size cap is prudent.
- The cached HTML must match the current CSS/plugin configuration. Cache key should include configuration hash.
- Requires JS-side API addition (`setRenderedHTML`).

**Complexity:** Medium. Requires JS and Swift changes, plus cache management.

---

### C-4: Deferred Off-Screen Rendering

**Problem:** SwiftUI List may trigger `makeUIView` for rows that are not yet visible (prefetching). This creates WebViews that compete for resources with visible cells.

**Design:** Defer `loadHTMLString` until the MarkdownView is actually visible. Use `willMove(toWindow:)` or `didMoveToWindow` as the trigger.

```swift
open override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, let request = deferredRenderRequest {
        deferredRenderRequest = nil
        renderMarkdown(markdown: request.markdown, enableImage: request.enableImage)
    }
}
```

**Estimated impact:** Reduces resource contention during fast scrolling. Prioritizes visible cells.

**Risks:**
- Slight delay before content appears (blank cell until render). Mitigate with C-2 (cached height for correct sizing) and a placeholder.
- Interaction with C-1 (recycling) needs careful ordering.

**Complexity:** Low.

---

## Measurement Plan

Before implementing, establish baselines with the `SampleListUI` (80 rows):

1. **Instruments → Time Profiler**: Measure `configureWebView` and `renderMarkdown` per cell
2. **Instruments → Allocations**: Track WKWebView instance count during scroll
3. **Instruments → Core Animation (CADisplayLink)**: Measure dropped frames during fast scroll
4. **Manual timing**: Add `os_signpost` around key operations:

```swift
import os.signpost

private let signpostLog = OSLog(subsystem: "com.keita.oouchi.MarkdownView", category: "Performance")

// In configureWebView:
let id = OSSignpostID(log: signpostLog)
os_signpost(.begin, log: signpostLog, name: "configureWebView", signpostID: id)
// ... existing code ...
os_signpost(.end, log: signpostLog, name: "configureWebView", signpostID: id)
```

5. **Automated benchmark**: Add a `PerformanceTests` target that measures scroll-to-bottom time programmatically.

---

## Recommended Implementation Order

```
Phase 1: Quick wins (low risk, high impact)
  C-2  Height Cache                    ← Eliminates layout flicker immediately
  C-4  Deferred Off-Screen Rendering   ← Reduces resource contention

Phase 2: Core optimization (medium risk, highest impact)
  C-1  WebView Recycling              ← Eliminates per-cell creation cost
  C-3  Rendered HTML Cache             ← Further reduces redundant work with C-1
```

### Expected Cumulative Impact

| Metric | Current (80 cells) | C-1+C-2+C-4 | C-1+C-2+C-3+C-4 |
|---|---|---|---|
| WKWebView instances alive | Up to 80 | Pool max (3-5) | Pool max (3-5) |
| Cold cell render | 160-350 ms | 160-350 ms | 160-350 ms |
| Scroll-back cell render | 160-350 ms | ~20-50 ms | ~10-20 ms |
| Layout flicker on scroll-back | Yes | No | No |
| Memory (WebContent processes) | Unbounded | Bounded | Bounded |
| Fast scroll jank | Significant | Mild | Minimal |

---

## Open Questions

### Resolved

4. **iOS 26 `WebView` (SwiftUI native)** — Investigated. The new `WebView`/`WebPage` API (iOS 26) does not provide automatic view recycling in `List`. C-1 through C-4 remain valuable for all supported OS versions (iOS 16+). Future migration to `WebView`/`WebPage` is a separate concern, not a blocker.

5. **`willMove(toWindow:)` reliability** — **Confirmed reliable.** `willMove(toWindow: nil)` fires consistently on scroll-out in `SampleListUI` (80 rows). See [Lifecycle Verification Results](#lifecycle-verification-results) below.

6. **`UIViewRepresentable` lifecycle / best recycle trigger** — **`willMove(toWindow: nil)` is the best trigger.** See [Lifecycle Verification Results](#lifecycle-verification-results) for full ordering analysis.

7. **WKWebView reset cost** — Baseline recorded: `Pool.createAndEnpool` measures new-creation cost. C-1 implementation will compare reset (`loadHTMLString` on existing WebView) against this baseline. Threshold: reset < 50% of creation → C-1 is viable.

### To verify (post C-1 implementation)

- **WKWebView reset cost vs creation cost** — After C-1 `enqueue()` is implemented, measure the actual reset duration with `os_signpost` and compare against the `Pool.createAndEnpool` baseline.

---

## Lifecycle Verification Results

Empirical validation performed on `SampleListUI` (80 rows) with `os_signpost` instrumentation and lifecycle logging. Instrumentation code lives in `MarkdownLifecycleLogger.swift` (DEBUG-only).

### Key Finding: SwiftUI List Does NOT Reuse UIView Instances

Every `makeUIView` call creates a new `MarkdownView` with a unique `lifecycleId`. When a cell scrolls back into view, SwiftUI creates a brand new UIView — it does **not** reuse the old one (unlike `UITableView` cell reuse). This means every scroll event incurs the full WKWebView creation cost.

### Lifecycle Event Ordering (Scroll-Out)

Observed consistent ordering during scroll:

```
1. makeUIView              ← New UIView created (new lifecycleId)
2. Pool.dequeue miss       ← Pool empty, new WKWebView created
3. updateUIView            ← SwiftUI pushes state
4. willMove(toWindow: window) ← New view enters window
5. willMove(toWindow: nil)    ← OLD view leaves window
6. dismantleUIView            ← OLD view dismantled by SwiftUI
7. onDisappear                ← Row-level callback (batched, delayed)
```

### Trigger Suitability for C-1 Recycling

| Trigger | Fires on Scroll-Out | Timing | Batched? | C-1 Suitability |
|---|---|---|---|---|
| `willMove(toWindow: nil)` | Yes, consistently | Earliest | No | **Best** — immediate, per-view |
| `dismantleUIView` | Yes, but delayed | After `willMove` | Sometimes | Good — reliable but later |
| `onDisappear` | Yes | Latest | Yes, heavily | **Not suitable** — too late, batched |

### Observations

- **Pool always misses**: Every `dequeue` returned `nil` because WebViews are never returned to the pool. This confirms C-1 (bidirectional recycling) is the critical optimization.
- **`updateUIView` called excessively**: SwiftUI re-evaluates and calls `updateUIView` far more than expected (20+ calls per visible set), even without state changes. C-1 should be resilient to redundant `updateUIView` calls.
- **`dismantleUIView` on navigation back**: When navigating back from the List, all remaining views receive `dismantleUIView` in a batch. This is a cleanup event, not a scroll-out event.
- **New UIView created before old one removed**: SwiftUI's order is create-new → attach-new → detach-old → dismantle-old. C-1's `enqueue` must handle the case where the old WebView is returned to the pool slightly after the new one tries to dequeue.

### C-1 Design Confirmation

The verification confirms the C-1 design in this document is viable:

```
willMove(toWindow: nil) → detach WKWebView → enqueue to Pool (reset content)
makeUIView              → dequeue from Pool → attach to new MarkdownView
```

The pool should maintain a small buffer (3-5 WebViews) to absorb the timing gap between new-view creation and old-view return.
