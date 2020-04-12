import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
open class MarkdownView: UIView {

  private var webView: WKWebView?
  
  fileprivate var intrinsicContentHeight: CGFloat? {
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
    self.init(frame: CGRect.zero)
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  open override var intrinsicContentSize: CGSize {
    if let height = self.intrinsicContentHeight {
      return CGSize(width: UIView.noIntrinsicMetric, height: height)
    } else {
      return CGSize.zero
    }
  }

  @objc public func load(markdown: String?, enableImage: Bool = true) {
    guard let markdown = markdown else {
        #if DEBUG
        print("ERROR: markdown string not passed into load() function, returning")
        #endif
        return
    }

    // setup bundle url and holder for optional htmlURL var
    let bundle = Bundle(for: MarkdownView.self)
    var htmlURL: URL? = nil
    
    // Enables handling different bundle URL formatting for catalyst environment
    #if targetEnvironment(macCatalyst)
        #if DEBUG
        print("using htmlURL formatted for mac catalyst environment")
        #endif
        htmlURL = bundle.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "MarkdownView.bundle/Contents/Resources")
        
        #if DEBUG
        print("htmlURL: \(htmlURL?.absoluteString ?? "error, htmlURL was nil!")")
        #endif
    // handle bundle URL formatting for iOS envs
    #else
        #if DEBUG
         print("using htmlURL formatted for iOS environment")
        #endif
         htmlURL =
             bundle.url(forResource: "index",
                       withExtension: "html") ??
             bundle.url(forResource: "index",
                       withExtension: "html",
                           subdirectory: "MarkdownView.bundle")
        #if DEBUG
        print("htmlURL: \(htmlURL?.absoluteString ?? "error, htmlURL was nil!")")
        #endif
    #endif
    
    // ensure htmlURL is assigned & handle nil value
    guard let url = htmlURL else {
        #if DEBUG
        print("\nWARNING: markdownView.swift: htmlurl could not be loaded: this is likely due to running this application in unsupported environment.\n")
        #endif
        return
    }
    
    // format & setup markdownview
    let escapedMarkdown = self.escape(markdown: markdown) ?? ""
    let imageOption = enableImage ? "true" : "false"
    let script = "window.showMarkdown('\(escapedMarkdown)', \(imageOption));"
    let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    
    // setup wk config
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
    
    // use wk to load, but using catalyst && iOS compatible func
    wv.loadFileURL(url, allowingReadAccessTo: url)
  }

  private func escape(markdown: String) -> String? {
    return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
  }

}

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = "document.body.scrollHeight;"
    webView.evaluateJavaScript(script) { [weak self] result, error in
      if let _ = error { return }

      if let height = result as? CGFloat {
        self?.onRendered?(height)
        self?.intrinsicContentHeight = height
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
