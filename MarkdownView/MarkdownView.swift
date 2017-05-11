import UIKit
import WebKit

open class MarkdownView: UIView {

  private var webView: WKWebView!
  fileprivate var escapedMarkdown: String?
  private var requestHtml: URLRequest?

  public var delegate: MarkdownViewDelegate?

  convenience init () {
    self.init(frame:CGRect.zero)
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
    setUp()
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setUp() {
    let bundle = Bundle(for: MarkdownView.self)
    let path = bundle.path(forResource: "MarkdownView.bundle/index", ofType:"html")
    requestHtml = URLRequest(url: URL(fileURLWithPath: path!))

    webView = WKWebView()
    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.navigationDelegate = self
    addSubview(webView)
    webView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
    webView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
    webView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
    webView.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
    webView.backgroundColor = self.backgroundColor
  }

  public func load(markdown: String?) {
    guard let url = requestHtml, let markdown = markdown else {
      return
    }

    self.escapedMarkdown = self.escape(markdown: markdown)
    webView.load(url)
  }

  private func escape(markdown: String) -> String {
    return markdown
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "'", with: "\\'")
  }

}

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard let escapedMarkdown = escapedMarkdown else { return }

    let script = "window.showMarkdown('\(escapedMarkdown)');"
    webView.evaluateJavaScript(script)
  }

  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

    if let delegate = delegate {
      delegate.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    } else if let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) {
      decisionHandler(.allow)
    } else {
      decisionHandler(.cancel)
    }
  }

}

public protocol MarkdownViewDelegate {

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)

}
