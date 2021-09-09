import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
open class MarkdownView: UIView {

  private var webView: WKWebView?
  
  private var intrinsicContentHeight: CGFloat? {
    didSet {
      self.invalidateIntrinsicContentSize()
    }
  }

  @objc public var isScrollEnabled: Bool = true {
    didSet {
      webView?.scrollView.isScrollEnabled = isScrollEnabled
    }
  }

  @objc public var onTouchLink: ((URLRequest) -> Bool)?

  @objc public var onRendered: ((CGFloat) -> Void)?

  public convenience init() {
    self.init(frame: .zero)
  }

  /// Reserve a web view before displaying markdown.
  /// You can use this for performance optimization.
  ///
  /// - Note: `webView` needs complete loading before invoking `show` method.
  public convenience init(css: String?, plugins: [String]?) {
    self.init(frame: .zero)
    
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(css: css, plugins: plugins, markdown: nil, enableImage: nil)
    self.webView = makeWebView(with: configuration)
    self.webView?.load(URLRequest(url: htmlURL))
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}

extension MarkdownView {
  open override var intrinsicContentSize: CGSize {
    if let height = self.intrinsicContentHeight {
      return CGSize(width: UIView.noIntrinsicMetric, height: height)
    } else {
      return CGSize.zero
    }
  }

  /// Load markdown with a newly configured webView.
  ///
  /// If you want to preserve already applied css or plugins, use `show` instead.
  @objc public func load(markdown: String?, enableImage: Bool = true, css: String? = nil, plugins: [String]? = nil) {
    guard let markdown = markdown else { return }

    self.webView?.removeFromSuperview()
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = makeContentController(css: css, plugins: plugins, markdown: markdown, enableImage: enableImage)
    self.webView = makeWebView(with: configuration)
    self.webView?.load(URLRequest(url: htmlURL))
  }
  
  public func show(markdown: String) {
    guard let webView = webView else { return }

    let escapedMarkdown = self.escape(markdown: markdown) ?? ""
    let script = "window.showMarkdown('\(escapedMarkdown)', true);\(evaluateHeightScript)"
    webView.evaluateJavaScript(script) { [weak self] result, error in
      if let _ = error { return }

      if let height = result as? CGFloat {
        self?.onRendered?(height)
        self?.intrinsicContentHeight = height
      }
    }
  }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    evaluateHeight(in: webView)
  }

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    switch navigationAction.navigationType {
    case .linkActivated:
      if let onTouchLink = onTouchLink, onTouchLink(navigationAction.request) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    default:
      decisionHandler(.allow)
    }

  }

}

// MARK: - Scripts

private extension MarkdownView {
  var evaluateHeightScript: String {
    [
      "var _body = document.body;",
      "var _html = document.documentElement;",
      "Math.max(_body.scrollHeight, _body.offsetHeight, _html.clientHeight, _html.scrollHeight, _html.offsetHeight);"
    ].joined()
  }
  
  func styleScript(_ css: String) -> String {
    [
      "var s = document.createElement('style');",
      "s.innerHTML = `\(css)`;",
      "document.head.appendChild(s);"
    ].joined()
  }
  
  func usePluginScript(_ pluginBody: String) -> String {
    """
      var _module = {};
      var _exports = {};
      (function(module, exports) {
        \(pluginBody)
      })(_module, _exports);
      window.usePlugin(_module.exports || _exports);
    """
  }
}

// MARK: - Misc

private extension MarkdownView {
  func escape(markdown: String) -> String? {
    return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
  }
  
  func evaluateHeight(in webView: WKWebView) {
    webView.evaluateJavaScript(evaluateHeightScript) { [weak self] result, error in
      if let _ = error { return }

      if let height = result as? CGFloat {
        self?.onRendered?(height)
        self?.intrinsicContentHeight = height
      }
    }
  }

  func makeWebView(with configuration: WKWebViewConfiguration) -> WKWebView {
    let wv = WKWebView(frame: self.bounds, configuration: configuration)
    wv.scrollView.isScrollEnabled = self.isScrollEnabled
    wv.translatesAutoresizingMaskIntoConstraints = false
    wv.navigationDelegate = self
    addSubview(wv)
    wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
    wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
    wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
    wv.isOpaque = false
    wv.backgroundColor = .clear
    wv.scrollView.backgroundColor = .clear
    return wv
  }
  
  func makeContentController(css: String?, plugins: [String]?, markdown: String?, enableImage: Bool?) -> WKUserContentController {
    let controller = WKUserContentController()
    
    if let css = css {
      let styleInjection = WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(styleInjection)
    }
    
    plugins?.forEach({ plugin in
      let scriptInjection = WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(scriptInjection)
    })
    
    if let markdown = markdown {
      let escapedMarkdown = self.escape(markdown: markdown) ?? ""
      let imageOption = (enableImage ?? true) ? "true" : "false"
      let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));"
      let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(userScript)
    }

    return controller
  }
}
