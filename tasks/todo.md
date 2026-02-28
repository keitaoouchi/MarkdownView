# TODO

- [x] 1. `Example` の `project.pbxproj` を CocoaPods 依存から SwiftPM ローカル依存へ置換する
- [x] 2. `Example.xcworkspace` から Pods 参照を除去する
- [x] 3. CocoaPods 運用ファイル（`Podfile`/`Pods`/`podspec`/`Gemfile`）を削除する
- [x] 4. README / AGENTS の CocoaPods 記述を削除し、SwiftPM 主体に更新する
- [x] 5. `xcodebuild` で `MarkdownView` と `Example` のビルド検証を行う
- [x] 6. 実施結果を `Review` に記録する

# Review

- [x] 1. `Example` の `project.pbxproj` を CocoaPods 依存から SwiftPM ローカル依存へ置換する
- [x] 2. `Example.xcworkspace` から Pods 参照を除去する
- [x] 3. CocoaPods 運用ファイル（`Podfile`/`Pods`/`podspec`/`Gemfile`）を削除する
- [x] 4. README / AGENTS の CocoaPods 記述を削除し、SwiftPM 主体に更新する
- [x] 5. `xcodebuild` で `MarkdownView` と `Example` のビルド検証を行う
- [x] 6. 実施結果を `Review` に記録する

- `Example/Example.xcodeproj/project.pbxproj`:
  Pods の静的ライブラリ連携・`[CP]` スクリプト・Pods xcconfig を削除し、`XCLocalSwiftPackageReference`（`../`）+ `XCSwiftPackageProductDependency`（`MarkdownView`）へ移行。
- 削除ファイル/ディレクトリ:
  `MarkdownView.podspec`, `Example/Podfile`, `Example/Podfile.lock`, `Example/Gemfile`, `Example/Gemfile.lock`, `Example/Pods/`, `Example/Example.xcworkspace/`
- ドキュメント更新:
  `README.md` から CocoaPods バッジとインストール手順を削除、`AGENTS.md` の Distribution を Swift Package Manager のみに更新。
- 検証:
  1) `xcodebuild build -project MarkdownView.xcodeproj -scheme MarkdownView -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
  2) `xcodebuild build -project Example/Example.xcodeproj -scheme Example -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
  いずれも `** BUILD SUCCEEDED **`。
- 補足:
  `Example` ビルド時に deprecated API (`load(markdown:...)`) 警告は出るが、今回の SwiftPM 移行の成否には影響なし。
