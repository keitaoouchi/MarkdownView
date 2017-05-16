import UIKit
import WebKit

open class MarkdownView: UIView {

  private var webView: WKWebView?

  public var isScrollEnabled: Bool = true {

    didSet {
      webView?.scrollView.isScrollEnabled = isScrollEnabled
    }

  }

  public var onTouchLink: ((URLRequest) -> Bool)?

  public var onRendered: ((CGFloat) -> Void)?

  public convenience init() {
    self.init(frame: CGRect.zero)
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  public func load(markdown: String?) {
    guard let markdown = markdown else { return }

    let bundle = Bundle(for: MarkdownView.self)

    if let path = bundle.path(forResource: "MarkdownView.bundle/index", ofType:"html") {
      let templateRequest = URLRequest(url: URL(fileURLWithPath: path))

      let escapedMarkdown = self.escape(markdown: markdown)
      let script = "window.showMarkdown('\(escapedMarkdown)');"
      let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

      let controller = WKUserContentController()
      controller.addUserScript(userScript)

      let configuration = WKWebViewConfiguration()
      configuration.userContentController = controller

      let wv = WKWebView(frame: self.bounds, configuration: configuration)
      wv.scrollView.isScrollEnabled = self.isScrollEnabled
      wv.translatesAutoresizingMaskIntoConstraints = false
      wv.navigationDelegate = self
      addSubview(wv)
      wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
      wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
      wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
      wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
      wv.backgroundColor = self.backgroundColor

      self.webView = wv

      wv.load(templateRequest)
    } else {
      // TODO: raise error
    }
  }

  private func escape(markdown: String) -> String {
    return markdown
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "'", with: "\\'")
  }

}

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = "document.body.offsetHeight;"
    webView.evaluateJavaScript(script) { [weak self] result, error in
      if let _ = error { return }

      if let height = result as? CGFloat {
        self?.onRendered?(height)
      }
    }
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
