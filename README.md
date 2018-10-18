# MarkdownView

[![CI Status](http://img.shields.io/travis/keitaoouchi/MArkdownView.svg?style=flat)](https://travis-ci.org/keitaoouchi/MarkdownView)
[![Swift 4.2](https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat)](https://swift.org/)
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
| iOS               |  => 9.0 |
| Swift             |  => 4.2 |

## Installation

MarkdownView is available through [CocoaPods](http://cocoapods.org) or [Carthage](https://github.com/Carthage/Carthage).

### CocoaPods

```ruby
pod "MarkdownView"
```

### Carthage

```
github "keitaoouchi/MarkdownView"
```

for detail, please follow the [Carthage Instruction](https://github.com/Carthage/Carthage#if-youre-building-for-ios-tvos-or-watchos)


## Author

keita.oouchi, keita.oouchi@gmail.com

## License

[bootstrap](http://getbootstrap.com/) is licensed under [MIT license](https://github.com/twbs/bootstrap/blob/v4-dev/LICENSE).  
[highlight.js](https://highlightjs.org/) is licensed under [BSD-3-Clause license](https://github.com/isagalaev/highlight.js/blob/master/LICENSE).  
[markdown-it](https://markdown-it.github.io/) is licensed under [MIT license](https://github.com/markdown-it/markdown-it/blob/master/LICENSE).  

MarkdownView is available under the MIT license. See the LICENSE file for more info.
