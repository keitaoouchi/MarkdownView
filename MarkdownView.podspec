Pod::Spec.new do |s|
  s.name          = "MarkdownView"
  s.version       = "2.0.0"  # メジャーバージョンアップ
  s.summary       = "Markdown View for iOS."
  s.homepage      = "https://github.com/keitaoouchi/MarkdownView"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "keitaoouchi" => "keita.oouchi@gmail.com" }
  s.source        = { :git => "https://github.com/keitaoouchi/MarkdownView.git", :tag => "#{s.version}" }
  s.source_files  = [
    "Sources/MarkdownView/MarkdownView.swift",
    "Sources/MarkdownView/MarkdownUI.swift",
  ]
  s.resource_bundles = {
    'MarkdownView' => [
      'Sources/MarkdownView/Resources/*'
    ]
  }
  s.frameworks    = "Foundation", "WebKit"
  s.ios.deployment_target = "15.0"  # iOS 15+に引き上げ
  s.swift_version = '6.0'  # Swift 6対応
end
