# webassets — Agent Guide

This directory contains the web layer source bundled with MarkdownView
(an iOS WKWebView library), along with its build and test environment.

---

## Directory Structure

```
webassets/
├── build.mjs                  # esbuild build script
├── package.json               # Dependencies & npm scripts
├── playwright.config.js       # Playwright test configuration
├── src/
│   ├── js/
│   │   └── index.js           # JS entry point (sole source file)
│   └── css/
│       ├── bootstrap.css      # Bootstrap v3.3.7 (only .table / .container rules)
│       ├── gist.css           # highlight.js theme (gist)
│       ├── github.css         # GitHub Markdown styles
│       └── index.css          # Custom CSS (CSS variables & dark mode support)
└── tests/
    └── render.spec.js         # Playwright functional tests (16 cases)
```

Build artifacts are output **outside of `webassets/`**.

```
../Sources/MarkdownView/Resources/
├── main.js      # Bundled & minified (~715 KB)
└── main.css     # Same
```

---

## npm Scripts

| Command | Description |
|---------|-------------|
| `npm run build` | Bundle & minify with esbuild, output to `Sources/MarkdownView/Resources/` |
| `npm test` | Run headless Chromium tests with Playwright |

Installing dependencies is only required on first setup.

```sh
cd webassets
npm install
npm run build
npm test
```

---

## Build Configuration (build.mjs)

- **Bundler**: esbuild (replaces webpack + Babel)
- **Target**: `safari13` (supports WKWebView on iOS 13+)
- **Output**: IIFE format, minified
- **License comments**: `legalComments: 'none'` (no LICENSE.txt generated)

Build time is typically under 100 ms.

---

## JS Entry Point (src/js/index.js)

### Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| `highlight.js` | ^11.11.1 | Syntax highlighting |
| `markdown-it` | ^14.1.0 | Markdown parsing & rendering |
| `markdown-it-emoji` | ^3.0.0 | Emoji shortcode conversion |

### highlight.js Language Set

**113 languages are individually imported** into `highlight.js/lib/core`
(changed from bundling all 192 languages to reduce bundle size).

To add or remove languages, edit both the import statement and the
`hljs.registerLanguage()` call in `index.js` as a pair.

**Note**: `import markdownLang from "highlight.js/lib/languages/markdown"` uses
the alias `markdownLang` to avoid a variable name collision with
`let markdown = new MarkdownIt(...)`. Keep this in mind when renaming variables.

### markdown-it-emoji Import

Starting with v3, the default export was removed in favor of a named export.

```js
// Correct (v3+)
import { full as emoji } from "markdown-it-emoji";

// Wrong (v2 and earlier)
import emoji from "markdown-it-emoji";
```

### APIs Exposed on `window`

Called from the iOS Swift side via WKWebView's `evaluateJavaScript`.

| API | Signature | Description |
|-----|-----------|-------------|
| `window.showMarkdown` | `(percentEncodedMarkdown: string, enableImage?: boolean) => void` | Receives percent-encoded Markdown and renders it. When `enableImage=false`, images are hidden |
| `window.usePlugin` | `(plugin: MarkdownItPlugin) => void` | Public API to register a markdown-it plugin. Allows the Swift side to dynamically add plugins |

### WKWebView Callback

After rendering, the document height is sent to WKWebView.

```js
window?.webkit?.messageHandlers?.updateHeight?.postMessage(height);
```

The Swift side receives this via the `WKScriptMessageHandler`'s `updateHeight`
handler and updates the WebView's height constraint.

---

## CSS

CSS files are bundled together with JS by the build script.
**Edit them directly** (there is no separate build tool for CSS).

| File | Details |
|------|---------|
| `bootstrap.css` | Only `.table` and `.container` rules extracted from Bootstrap v3.3.7. No version upgrade needed |
| `gist.css` | highlight.js code color theme. Replace this file to change themes |
| `github.css` | GitHub-flavored Markdown decoration styles |
| `index.css` | Custom styles. Supports CSS variables and dark mode (`prefers-color-scheme`) |

---

## Tests (tests/render.spec.js)

16 functional tests using Playwright + headless Chromium.

### Test Environment Setup

`beforeEach` runs in the following order:

1. `page.setContent(...)` — Sets up minimal HTML with `<div id="contents">`
2. `page.evaluate(...)` — Injects a `window.webkit.messageHandlers.updateHeight` mock
3. `page.addScriptTag(...)` — Loads the built `main.js`

**Important**: The WKWebView mock is injected via `page.evaluate` (after setContent),
not `addInitScript`. In headless shell environments, `addInitScript` may not
reliably preserve `window` properties.

### Test Categories

| Category | Count |
|----------|-------|
| Basic rendering (h1/h2, paragraphs, lists, bold, inline code) | 6 |
| highlight.js (hljs class assignment, Swift, Python) | 3 |
| Emoji shortcode conversion | 1 |
| Bootstrap table class injection | 1 |
| Image control (enableImage true/false) | 2 |
| WebKit height notification | 1 |
| Edge cases (empty string, multiple-call overwrite) | 2 |

### Test Prerequisites

- A built `main.js` must exist (via `npm run build`)
- A Playwright-compatible Chromium must be present at `/root/.cache/ms-playwright/`
  (`npx playwright install` may fail in network-restricted environments)

---

## Common Pitfalls

### Adding a highlight.js Language

**Both** an import statement and an `hljs.registerLanguage()` call are required.
Adding only one will not work.

```js
// 1. Add import
import cobol from "highlight.js/lib/languages/cobol";

// 2. Add registration
hljs.registerLanguage('cobol', cobol);
```

### The `markdown` Variable Name

`let markdown = new MarkdownIt(...)` already declares a variable named `markdown`.
When importing the highlight.js markdown language module, always use an alias.

```js
// Correct
import markdownLang from "highlight.js/lib/languages/markdown";
hljs.registerLanguage('markdown', markdownLang);

// Build error
import markdown from "highlight.js/lib/languages/markdown"; // Name collision
```

### Changing the Build Output Path

If you change `outdir` in `build.mjs`, also update `mainJsPath` in
`tests/render.spec.js` accordingly.

```js
// tests/render.spec.js
const mainJsPath = resolve(__dirname, '../../Sources/MarkdownView/Resources/main.js');
```
