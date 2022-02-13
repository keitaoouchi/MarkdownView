# MarkdownView

[![CI Status](http://img.shields.io/travis/keitaoouchi/MArkdownView.svg?style=flat)](https://travis-ci.org/keitaoouchi/MarkdownView)
[![Swift 5.2](https://img.shields.io/badge/Swift-5.2-orange.svg?style=flat)](https://swift.org/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)
[![License](https://img.shields.io/cocoapods/l/MarkdownView.svg?style=flat)](http://cocoapods.org/pods/MarkdownView)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

> MarkdownView is a WKWebView based UI element, and internally use markdown-it, highlight-js.

![GIF](https://github.com/keitaoouchi/MarkdownView/blob/master/sample.gif "GIF")

## How to use

#### UIViewController

```swift
import MarkdownView

let md = MarkdownView()
md.load(markdown: "# Hello World!")
```

#### SwiftUI

```swift
import SwiftUI
import MarkdownView

struct SampleUI: View {
  var body: some View {
    ScrollView {        
      MarkdownUI(body: markdown)
        .onTouchLink { link in 
          print(link)
          return false
        }
        .onRendered { height in 
          print(height)
        }
    }
  }
  
  private var markdown: String {
    let path = Bundle.main.path(forResource: "sample", ofType: "md")!
    let url = URL(fileURLWithPath: path)
    return try! String(contentsOf: url, encoding: String.Encoding.utf8)
  }
}

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

### Experimental Features

This is not stable :bow:

#### Custom CSS Styling

Please check [Example/ViewController/CustomCss.swift](https://github.com/keitaoouchi/MarkdownView/blob/master/Example/Example/ViewController/CustomCss.swift). 

<img src="https://github.com/keitaoouchi/MarkdownView/blob/master/sample_css.png" width=300>

#### Plugins

Please check [Example/ViewController/Plugins.swift](https://github.com/keitaoouchi/MarkdownView/blob/master/Example/Example/ViewController/Plugins.swift). 
Each plugin should be self-contained, with no external dependent plugins.

<img src="https://github.com/keitaoouchi/MarkdownView/blob/master/sample_plugin.png" width=300>

[Here](https://github.com/keitaoouchi/markdownview-sample-plugin) is a sample project that builds `markdown-it-new-katex` as a compatible library.

## Requirements

| Target            | Version |
|-------------------|---------|
| iOS               |  => 13.0 |
| Swift             |  => 5.2 |

## Installation

MarkdownView is available through [Swift Package Manager](https://swift.org/package-manager/) or [CocoaPods](http://cocoapods.org) or [Carthage](https://github.com/Carthage/Carthage).

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/keitaoouchi/MarkdownView.git", from: "1.7.1")
]
```
Alternatively, you can add the package directly via Xcode.

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
