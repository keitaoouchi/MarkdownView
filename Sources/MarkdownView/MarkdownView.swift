import UIKit
import WebKit

/**
 Markdown View for iOS.
 
 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
@MainActor
open class MarkdownView: UIView {

  private var webView: WKWebView? = nil
  private var updateHeightHandler: UpdateHeightHandler? = nil
  
  private var intrinsicContentHeight: CGFloat? = nil {
    didSet {
      self.invalidateIntrinsicContentSize()
    }
  }

  @objc public var isScrollEnabled: Bool = true {
    didSet {
      webView?.scrollView.isScrollEnabled = isScrollEnabled
    }
  }

  public var onTouchLink: (@MainActor (URLRequest) -> Bool)?
  public var onRendered: (@MainActor (CGFloat) -> Void)?

  public convenience init() {
    self.init(frame: .zero)
  }

  /// Reserve a web view before displaying markdown.
  /// You can use this for performance optimization.
  ///
  /// - Note: `webView` needs complete loading before invoking `show` method.
  public convenience init(
      css: String? = nil,
      plugins: [String]? = nil,
      stylesheets: [URL]? = nil,
      styled: Bool = true
  ) {
      self.init(frame: .zero)
      
      Task { @MainActor in
          await setupWebView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
      }
  }

  override init (frame: CGRect) {
    super.init(frame : frame)
    setupUpdateHeightHandler()
  }
  
  private func setupUpdateHeightHandler() {
      let updateHeightHandler = UpdateHeightHandler { [weak self] height in
          Task { @MainActor in
              guard let self = self,
                    height > self.intrinsicContentHeight ?? 0 else { return }
              self.onRendered?(height)
              self.intrinsicContentHeight = height
          }
      }
      self.updateHeightHandler = updateHeightHandler
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
  public func load(
      markdown: String?,
      enableImage: Bool = true,
      css: String? = nil,
      plugins: [String]? = nil,
      stylesheets: [URL]? = nil,
      styled: Bool = true
  ) async {
      guard let markdown = markdown else { return }
      
      await setupWebView(
          css: css,
          plugins: plugins,
          stylesheets: stylesheets,
          markdown: markdown,
          enableImage: enableImage,
          styled: styled
      )
  }
  
  public func show(markdown: String) async {
      guard let webView = webView else { return }
      
      let escapedMarkdown = escape(markdown: markdown) ?? ""
      let script = "window.showMarkdown('\(escapedMarkdown)', true);"
      
      do {
          _ = try await webView.evaluateJavaScript(script)
      } catch {
          print("[MarkdownView][Error] \(error)")
      }
  }
  
  private func setupWebView(
      css: String? = nil,
      plugins: [String]? = nil,
      stylesheets: [URL]? = nil,
      markdown: String? = nil,
      enableImage: Bool? = nil,
      styled: Bool = true
  ) async {
      webView?.removeFromSuperview()
      
      let configuration = WKWebViewConfiguration()
      
      // iOS 15+ の新しいAPI使用
      configuration.defaultWebpagePreferences.allowsContentJavaScript = true
      
      configuration.userContentController = makeContentController(
          css: css,
          plugins: plugins,
          stylesheets: stylesheets,
          markdown: markdown,
          enableImage: enableImage
      )
      
      if let handler = self.updateHeightHandler { // Ensure self.updateHeightHandler is used
          configuration.userContentController.add(handler, name: "updateHeight")
      }
      
      let newWebView = makeWebView(with: configuration)
      self.webView = newWebView
      
      let url = styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl
      do {
          // WKWebView.load(_:) is not async. The async version is loadFileURL(_:allowingReadAccessTo:) or custom async wrappers.
          // For now, sticking to the original non-async load for URLRequest.
          // If a specific async behavior for load is needed, it would require more changes.
          _ = newWebView.load(URLRequest(url: url))
      } // Removed try/catch as load(URLRequest) is not throwing and not async.
      // If async loading with error handling is desired, it should be:
      // do {
      //   _ = try await newWebView.load(URLRequest(url: url)) // This would require an extension or different load method
      // } catch {
      //   print("[MarkdownView][Error] Failed to load HTML: \(error)")
      // }
  }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {

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

// MARK: -
private class UpdateHeightHandler: NSObject, WKScriptMessageHandler {
  var onUpdate: ((CGFloat) -> Void)
  
  init(onUpdate: @escaping (CGFloat) -> Void) {
    self.onUpdate = onUpdate
  }
  
  public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    switch message.name {
    default:
      if let height = message.body as? CGFloat {
        self.onUpdate(height)
      }
    }
  }
}

// MARK: - Scripts

private extension MarkdownView {
  
  func styleScript(_ css: String) -> String {
    [
      "var s = document.createElement('style');",
      "s.innerHTML = `\(css)`;",
      "document.head.appendChild(s);"
    ].joined()
  }
  
  func linkScript(_ url: URL) -> String {
    [
      "var link = document.createElement('link');",
      "link.href = '\(url.absoluteURL)';",
      "link.rel = 'stylesheet';",
      "document.head.appendChild(link);"
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

// MARK: - Resource Management

private extension MarkdownView {
    
    static var styledHtmlUrl: URL = {
        guard let url = Bundle.module.url(forResource: "styled", withExtension: "html", subdirectory: "Resources") else {
            fatalError("Could not find styled.html in bundle resources. Check that `Resources` directory is correctly included in the target and `Package.swift` resource processing is set to `.process` or `.copy` if it contains subdirectories.")
        }
        return url
    }()
    
    static var nonStyledHtmlUrl: URL = {
        guard let url = Bundle.module.url(forResource: "non_styled", withExtension: "html", subdirectory: "Resources") else {
            fatalError("Could not find non_styled.html in bundle resources. Check that `Resources` directory is correctly included in the target and `Package.swift` resource processing is set to `.process` or `.copy` if it contains subdirectories.")
        }
        return url
    }()
}

// MARK: - Misc

private extension MarkdownView {
  func escape(markdown: String) -> String? {
    return markdown.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
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
  
  func makeContentController(css: String?,
                             plugins: [String]?,
                             stylesheets: [URL]?,
                             markdown: String?,
                             enableImage: Bool?) -> WKUserContentController {
    let controller = WKUserContentController()
    
    if let css = css {
      let styleInjection = WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(styleInjection)
    }
    
    plugins?.forEach({ plugin in
      let scriptInjection = WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(scriptInjection)
    })
    
    stylesheets?.forEach({ url in
      let linkInjection = WKUserScript(source: linkScript(url), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      controller.addUserScript(linkInjection)
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
