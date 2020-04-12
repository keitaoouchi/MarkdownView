# MarkdownView

[![CI Status](http://img.shields.io/travis/keitaoouchi/MArkdownView.svg?style=flat)](https://travis-ci.org/keitaoouchi/MarkdownView)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat)](https://swift.org/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)
[![License](https://img.shields.io/cocoapods/l/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)

> MarkdownView is a WKWebView based UI element, and internally use bootstrap, highlight.js, markdown-it.

![GIF](https://github.com/keitaoouchi/MarkdownView/blob/master/sample.gif "GIF")

## How to use

```swift
import MarkdownView

let md = MarkdownView()
md.load(markdown: "# Hello World!")
```

### Options

```swift
md.isScrollEnabled = false

// called when rendering finished
md.onRendered = { [weak self] height in
  self?.mdViewHeight.constant = height
  self?.view.setNeedsLayout()
}

// called when user touch link
md.onTouchLink = { [weak self] request in
  guard let url = request.url else { return false }

  if url.scheme == "file" {
    return false
  } else if url.scheme == "https" {
    let safari = SFSafariViewController(url: url)
    self?.navigationController?.pushViewController(safari, animated: true)
    return false
  } else {
    return false
  }
}
```

## Requirements

| Target            | Version |
|-------------------|---------|
| iOS               |  => 13.0        |
| macCatalyst       |  => macOS 10.15 |
| Swift             |  => 5.0         |

## Installation

MarkdownView for iOS and macCatalyst with SwiftPM support is only available through [GigabiteLabs](https://github.com/gigabitelabs/markdownview)

### Swift Package Manager

Incorporation via SPM will typically be the easiset and most performant way to use this framework (fastest time to compile, less re-compiling / fussing with cocoapods).

1. Open your Xcode project / workspace
2. Go to `file>Swift Packages>Add Package Dependency`
3. Target the master branch of this repo [https://github.com/GigabiteLabs/MarkdownView]()
4. Choose latest release by tag version, or just target master for the latest
5. All set

### CocoaPods

```ruby
pod "MarkdownView"
```

## Author

Originally by:
keita.oouchi, keita.oouchi@gmail.com

Catalyst & Swift Package Manager support by:
[Dan Burkhardt](https://github.com/danburkhardt), Founder and Lead Engineer @[GigabiteLabs](https://gigabitelabs.com)

## License

[bootstrap](http://getbootstrap.com/) is licensed under [MIT license](https://github.com/twbs/bootstrap/blob/v4-dev/LICENSE).  
[highlight.js](https://highlightjs.org/) is licensed under [BSD-3-Clause license](https://github.com/isagalaev/highlight.js/blob/master/LICENSE).  
[markdown-it](https://markdown-it.github.io/) is licensed under [MIT license](https://github.com/markdown-it/markdown-it/blob/master/LICENSE).  

MarkdownView is available under the MIT license. See the LICENSE file for more info.
