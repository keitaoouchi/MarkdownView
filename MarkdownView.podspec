Pod::Spec.new do |s|
  s.name          = "MarkdownView"
  s.version       = "1.6.0"
  s.summary       = "Markdown View for iOS."
  s.homepage      = "https://github.com/keitaoouchi/MarkdownView"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "keitaoouchi" => "keita.oouchi@gmail.com" }
  s.source        = { :git => "https://github.com/keitaoouchi/MarkdownView.git", :tag => "#{s.version}" }
  s.source_files  = "MarkdownView/*.swift"
  s.resource_bundles = {
    'MarkdownView' => ['webassets/dist/*']
  }
  s.frameworks    = "Foundation"
  s.ios.deployment_target = "10.0"
  s.swift_version = '5.0'
end
