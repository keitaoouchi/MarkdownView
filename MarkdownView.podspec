Pod::Spec.new do |s|
  s.name          = "MarkdownView"
  s.version       = "2.0.1"
  s.summary       = "Markdown View for iOS & macCatalyst applications."
  s.homepage      = "https://github.com/gigabitelabs/MarkdownView"
  s.license       = { :type => "MIT", :file => "LICENSE" }
  s.author        = { "keitaoouchi" => "keita.oouchi@gmail.com" }
  s.source        = { :git => "https://github.com/gigabitelabs/MarkdownView.git", :tag => "#{s.version}" }
  s.source_files  = "MarkdownView/*.swift"
  s.resource_bundles = {
    'MarkdownView' => ['webassets/dist/*']
  }
  s.ios.frameworks = "Foundation"
  s.platform = :ios
  s.ios.deployment_target = "13.0"
  s.swift_version = '5.0'
end
