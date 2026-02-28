# Lessons

- 2026-02-28: SwiftLintの「最小ルール生成」は`only_rules`抽出ではなく、違反データから各ルールの最小しきい値を算出して設定する。
- しきい値を持たないルール（例: `force_cast`, `force_try`）は、コード修正なしで違反ゼロ化する場合 `disabled_rules` を検討する。
- 2026-02-28: ルールを特定ディレクトリだけ許容したい場合は、ルール単位 `excluded` ではなく nested config（`parent_config`）でディレクトリごとに上書きする。
- 2026-02-28: SwiftLintのディレクトリ別上書き設定（nested config）を使う場合、CIで`--config`を固定指定すると意図した子設定が効かないことがあるため、root実行時はデフォルト探索で確認する。
- 2026-02-28: `requestAnimationFrame`由来の高さ通知は非同期なので、E2Eテストは即時配列参照ではなく`waitForFunction`で通知発生を待ってから検証する。
