Pod::Spec.new do |s|
  s.name          = "MarkdownView"
  s.version       = "1.9.1"
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
      'Sources/MarkdownView/Resources/styled.html',
      'Sources/MarkdownView/Resources/non_styled.html',
      'Sources/MarkdownView/Resources/main.css',
      'Sources/MarkdownView/Resources/main.js'
    ]
  }
  s.frameworks    = "Foundation"
  s.ios.deployment_target = "13.0"
  s.swift_version = '5.2'
end
