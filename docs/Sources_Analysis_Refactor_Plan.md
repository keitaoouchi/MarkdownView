# Sources 全体分析（MarkdownView）

## 対象
- `Sources/MarkdownView/MarkdownView.swift`
- `Sources/MarkdownView/MarkdownUI.swift`
- `Sources/MarkdownView/Resources/main.js`（生成物）
- `webassets/src/js/index.js`（実ソース）

---

## 主要な問題点（現状）

### 1. Swift 側の責務集中と重複
- `MarkdownView` が以下を1クラスで同時に担っている。
  - `WKWebView` のライフサイクル管理
  - スクリプト構築（CSS/プラグイン/スタイルシート/Markdown 表示）
  - 高さイベント通知と intrinsic サイズ制御
  - ナビゲーション（リンクタップ）制御
- `init(frame:)` と `init(coder:)` で同一の `UpdateHeightHandler` 初期化が重複。
- `load(...)` と convenience `init(...)` で WebView 構成ロジックが重複。

**影響**
- 保守時の変更点が多く、回帰リスクが高い。
- テストしづらく、責務境界が曖昧。

---

### 2. Markdown 受け渡し方式の安全性・可読性
- Swift → JS の引き渡しが `addingPercentEncoding(.alphanumerics)` + `decodeURIComponent` 依存。
- `window.showMarkdown('...')` 文字列補間で JS を組み立てており、文字列の扱いが壊れやすい。

**影響**
- 特殊文字や巨大テキスト時の不具合調査コスト増。
- エスケープ仕様の理解コストが高く、認知負荷が大きい。

---

### 3. JS 側の状態管理が副作用的
- `enableImage = false` の場合、`markdown = markdown.disable("image")` でインスタンスを破壊的変更。
- 一度 image を disable すると、その後の表示にも設定が残る可能性がある。

**影響**
- 呼び出し順に依存するバグの温床。
- 再現性が低い不具合につながる。

---

### 4. ハイライト処理の計算コスト
- `highlight` コールバックで `highlightAuto`、さらに描画後に `highlightElement` を全 `pre code` に再実行。
- 実質二重ハイライトになり得る。

**影響**
- 大きい Markdown で描画時間増・スクロール体験悪化。

---

### 5. 言語登録数が過剰（bundle肥大 + 初期化コスト）
- `webassets/src/js/index.js` で 100 以上の言語を手動 import/register。

**影響**
- `main.js` サイズ増大、ロード時間増。
- 変更コスト・レビューコスト増。

---

### 6. main.js がミニファイ済み成果物のみ配布
- `Sources/MarkdownView/Resources/main.js` は読解困難。
- 実際の編集対象は `webassets/src/js/index.js` だが、変更導線が分散。

**影響**
- 調査/修正の立ち上がりが遅い。
- 生成・同期漏れリスク。

---

### 7. 高さ更新イベントのノイズ
- 画像ロードごとに `postDocumentHeight()` 実行。
- 高さが変わらないケースも含め複数イベント発火。

**影響**
- Swift 側レイアウト再計算が過剰になりやすい。
- 画面更新のジッター要因。

---

### 8. API 設計上の混乱ポイント
- `load(markdown:...)` と `show(markdown:)` の責務差が利用者視点で分かりにくい。
- `show` は `enableImage` を指定できないなど、機能差が直感的でない。

**影響**
- 利用側で誤用しやすい。
- API 学習コスト増。

---

### 9. 観測性（ログ/計測）の不足
- エラーは `print` のみで、描画時間・JS処理時間・高さ更新回数の可視化がない。

**影響**
- パフォーマンス劣化時の原因特定が難しい。

---

## 改善案（優先度つき）

## P0（先に着手すべき）
1. **Swift 側の責務分離**
   - `MarkdownWebViewFactory`（構成生成）
   - `MarkdownScriptBuilder`（注入JS組み立て）
   - `MarkdownEventBridge`（height/link の橋渡し）
   - `MarkdownView` はオーケストレーションのみに限定

2. **Markdown 受け渡しを安全化**
   - `evaluateJavaScript` 文字列補間をやめ、`WKScriptMessage` / JSON 経由の受け渡しへ。
   - 代替として Base64 エンコード + JS側 decode を採用（可逆性を明確化）。

3. **JS の破壊的状態変更を排除**
   - `createMarkdownRenderer(options)` のファクトリ化。
   - `enableImage` ごとに renderer を切り替える（immutable 方針）。

4. **ハイライトを単一経路に統一**
   - `highlightAuto` を使うなら `highlightElement` を削除。
   - 逆に `highlightElement` を使うなら `markdown-it` 側 highlight コールバックを無効化。

## P1（中期）
5. **言語セットを設定化**
   - デフォルト最小セット（例: swift/js/json/bash/markdown）
   - 拡張セットをビルドフラグや別 bundle で opt-in

6. **高さ通知のデバウンス/差分通知**
   - JS 側で `requestAnimationFrame` + 前回値比較。
   - Swift 側でも一定閾値未満の変化は無視。

7. **API の再整理**
   - `render(markdown:options:)` へ統一。
   - 初期構成変更が必要な場合のみ `reconfigure(...)` を提供。

8. **ビルド生成物の運用明文化**
   - `webassets -> Sources/Resources` の生成コマンドを CI で固定。
   - 差分チェックを CI に追加（生成漏れ防止）。

## P2（改善余地）
9. **観測性向上**
   - render 開始〜完了時間計測（native/web双方）。
   - 高さイベント回数、画像数、コードブロック数のデバッグメトリクス。

10. **テスト戦略の補強**
   - JS: snapshot/render 結果テスト（代表 Markdown ケース）。
   - Swift: script builder と options の unit test。
   - E2E: サンプル画面で高さ通知・リンク遷移を自動テスト。

---

## 推奨リファクタリング順序（段階的移行）
1. **内部APIの分離（外部API互換維持）**
2. **JS renderer immutable 化 + ハイライト統一**
3. **受け渡しフォーマットの安全化**
4. **高さ通知最適化**
5. **言語セット最小化**
6. **公開 API 整理（必要ならメジャーアップデート）**

---

## 期待効果
- 初期描画・再描画の安定性向上
- Webアセットサイズ削減による起動/ロード高速化
- 不具合再現性の向上（状態依存バグ削減）
- 機能追加時の認知負荷低減（責務分離により見通し改善）
