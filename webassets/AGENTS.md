# webassets — エージェント向けガイド

このディレクトリは MarkdownView（iOS WKWebView ライブラリ）が内包する
Web レイヤーのソースと、そのビルド・テスト環境一式です。

---

## ディレクトリ構成

```
webassets/
├── build.mjs                  # esbuild ビルドスクリプト
├── package.json               # 依存関係・npm スクリプト
├── playwright.config.js       # Playwright テスト設定
├── src/
│   ├── js/
│   │   └── index.js           # JS エントリポイント（唯一のソース）
│   └── css/
│       ├── bootstrap.css      # Bootstrap v3.3.7（.table / .container のみ抜粋）
│       ├── gist.css           # highlight.js テーマ（gist）
│       ├── github.css         # GitHub Markdown スタイル
│       └── index.css          # カスタム CSS（CSS 変数・ダークモード対応）
└── tests/
    └── render.spec.js         # Playwright 機能テスト（16 件）
```

ビルド成果物は **`webassets/` の外** に出力されます。

```
../Sources/MarkdownView/Resources/
├── main.js      # バンドル済み・最小化済み（~715 KB）
└── main.css     # 同上
```

---

## npm スクリプト

| コマンド | 内容 |
|---------|------|
| `npm run build` | esbuild でバンドル・最小化して `Sources/MarkdownView/Resources/` に出力 |
| `npm test` | Playwright でヘッドレス Chromium テストを実行 |

依存パッケージのインストールは初回のみ必要です。

```sh
cd webassets
npm install
npm run build
npm test
```

---

## ビルド設定（build.mjs）

- **バンドラ**: esbuild（webpack + Babel を置き換え）
- **ターゲット**: `safari13`（iOS 13 以降の WKWebView に対応）
- **出力**: IIFE 形式、最小化済み
- **ライセンスコメント**: `legalComments: 'none'`（LICENSE.txt を生成しない）

ビルド時間は通常 100 ms 未満です。

---

## JS エントリポイント（src/js/index.js）

### 依存ライブラリ

| ライブラリ | バージョン | 役割 |
|-----------|-----------|------|
| `highlight.js` | ^11.11.1 | シンタックスハイライト |
| `markdown-it` | ^14.1.0 | Markdown パース・レンダリング |
| `markdown-it-emoji` | ^3.0.0 | 絵文字ショートコード変換 |

### highlight.js の言語セット

`highlight.js/lib/core` に対して **113 言語を個別インポート** しています
（全 192 言語をバンドルする方式から変更し、バンドルサイズを削減）。

追加・削除する場合は `index.js` の import 宣言と `hljs.registerLanguage()` 呼び出しを
対で編集してください。

**注意**: `import markdownLang from "highlight.js/lib/languages/markdown"` は
`let markdown = new MarkdownIt(...)` との変数名衝突を避けるため `markdownLang` という
エイリアスを使用しています。変数名を変更する際はこの点に注意してください。

### markdown-it-emoji の import

v3 より default export が廃止され named export に変わりました。

```js
// 正しい（v3 以降）
import { full as emoji } from "markdown-it-emoji";

// 誤り（v2 以前の記法）
import emoji from "markdown-it-emoji";
```

### window に公開される API

iOS Swift 側から WKWebView の `evaluateJavaScript` を通じて呼び出されます。

| API | シグネチャ | 説明 |
|-----|-----------|------|
| `window.showMarkdown` | `(percentEncodedMarkdown: string, enableImage?: boolean) => void` | パーセントエンコードされた Markdown を受け取りレンダリングする。`enableImage=false` のとき画像を非表示にする |
| `window.usePlugin` | `(plugin: MarkdownItPlugin) => void` | markdown-it プラグインを登録する公開 API。Swift 側から動的にプラグインを追加できる |

### WKWebView へのコールバック

レンダリング後にドキュメント高さを WKWebView へ通知します。

```js
window?.webkit?.messageHandlers?.updateHeight?.postMessage(height);
```

Swift 側は `WKScriptMessageHandler` の `updateHeight` ハンドラで受信し、
WebView の高さ制約を更新します。

---

## CSS

CSS ファイルはビルドスクリプトで JS と共にバンドルされます。
**直接編集してください**（CSS 側には別途ビルドツールはありません）。

| ファイル | 内容・注意点 |
|---------|-------------|
| `bootstrap.css` | Bootstrap v3.3.7 から `.table` と `.container` 関連ルールのみ抜粋。バージョンアップ不要 |
| `gist.css` | highlight.js のコード配色テーマ。テーマを変えたい場合はここを置き換える |
| `github.css` | GitHub 風の Markdown 装飾スタイル |
| `index.css` | カスタムスタイル。CSS 変数とダークモード（`prefers-color-scheme`）に対応済み |

---

## テスト（tests/render.spec.js）

Playwright + headless Chromium による機能テスト 16 件。

### テスト環境のセットアップ

`beforeEach` は以下の順序で実行されます。

1. `page.setContent(...)` — `<div id="contents">` を持つ最小 HTML を設定
2. `page.evaluate(...)` — `window.webkit.messageHandlers.updateHeight` モックを注入
3. `page.addScriptTag(...)` — ビルド済みの `main.js` を読み込む

**重要**: WKWebView モックは `addInitScript` ではなく `page.evaluate`（setContent の後）
で注入しています。headless shell 環境では `addInitScript` が `window` プロパティを
確実に保持しないケースがあるためです。

### テストカテゴリ

| カテゴリ | 件数 |
|---------|------|
| 基本レンダリング（h1/h2・段落・リスト・太字・インラインコード） | 6 |
| highlight.js（hljs クラス付与・Swift・Python） | 3 |
| 絵文字ショートコード変換 | 1 |
| Bootstrap テーブルクラス注入 | 1 |
| 画像制御（enableImage true/false） | 2 |
| webkit 高さ通知 | 1 |
| エッジケース（空文字列・複数回呼び出し上書き） | 2 |

### テスト実行の前提

- `npm run build` でビルド済みの `main.js` が存在すること
- Playwright に対応した Chromium が `/root/.cache/ms-playwright/` に存在すること
  （ネットワーク制限がある環境では `npx playwright install` は失敗する可能性があります）

---

## よくある落とし穴

### highlight.js 言語を追加するとき

import 宣言と `hljs.registerLanguage()` の**両方**が必要です。片方だけ追加しても動きません。

```js
// 1. import 追加
import cobol from "highlight.js/lib/languages/cobol";

// 2. 登録追加
hljs.registerLanguage('cobol', cobol);
```

### `markdown` という変数名

`let markdown = new MarkdownIt(...)` が既に `markdown` という変数を宣言しています。
highlight.js の markdown 言語モジュールをインポートする際は必ず別名を使用してください。

```js
// 正しい
import markdownLang from "highlight.js/lib/languages/markdown";
hljs.registerLanguage('markdown', markdownLang);

// ビルドエラーになる
import markdown from "highlight.js/lib/languages/markdown"; // 変数名衝突
```

### ビルド出力パスの変更

`build.mjs` の `outdir` を変更した場合、`tests/render.spec.js` の `mainJsPath` も
合わせて更新してください。

```js
// tests/render.spec.js
const mainJsPath = resolve(__dirname, '../../Sources/MarkdownView/Resources/main.js');
```
