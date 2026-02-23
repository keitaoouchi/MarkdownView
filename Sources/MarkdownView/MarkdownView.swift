import UIKit
import WebKit

/**
 Markdown View for iOS.

 - Note: [How to get height of entire document with javascript](https://stackoverflow.com/questions/1145850/how-to-get-height-of-entire-document-with-javascript)
 */
open class MarkdownView: UIView {
  private static let minimumHeightDeltaToNotify: CGFloat = 0.1

  public struct RenderOptions {
    public let enableImage: Bool

    public init(enableImage: Bool = true) {
      self.enableImage = enableImage
    }
  }

  public struct ConfigurationOptions {
    public let css: String?
    public let plugins: [String]?
    public let stylesheets: [URL]?
    public let styled: Bool

    public init(css: String? = nil,
                plugins: [String]? = nil,
                stylesheets: [URL]? = nil,
                styled: Bool = true) {
      self.css = css
      self.plugins = plugins
      self.stylesheets = stylesheets
      self.styled = styled
    }
  }

  private struct PendingRenderRequest {
    let markdown: String
    let enableImage: Bool
  }

  private var webView: WKWebView?
  private var eventBridge: MarkdownEventBridge?
  private var isWebViewLoaded = false
  private var pendingRenderRequest: PendingRenderRequest?

  private let scriptBuilder = MarkdownScriptBuilder()
  private let webViewFactory = MarkdownWebViewFactory()

  private var intrinsicContentHeight: CGFloat? {
    didSet {
      invalidateIntrinsicContentSize()
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
  /// - Note: `webView` needs complete loading before invoking `render` method.
  public convenience init(css: String?, plugins: [String]?, stylesheets: [URL]? = nil, styled: Bool = true) {
    self.init(frame: .zero)
    reconfigure(
      with: ConfigurationOptions(
        css: css,
        plugins: plugins,
        stylesheets: stylesheets,
        styled: styled
      )
    )
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupEventBridge()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupEventBridge()
  }

  open override var intrinsicContentSize: CGSize {
    if let height = intrinsicContentHeight {
      CGSize(width: UIView.noIntrinsicMetric, height: height)
    } else {
      .zero
    }
  }

  /// Load markdown with a newly configured webView.
  ///
  /// If you want to preserve already applied css or plugins, use `render` instead.
  @available(*, deprecated, message: "Use reconfigure(...) then render(markdown:options:) instead.")
  @objc public func load(markdown: String?,
                         enableImage: Bool = true,
                         css: String? = nil,
                         plugins: [String]? = nil,
                         stylesheets: [URL]? = nil,
                         styled: Bool = true) {
    guard let markdown else { return }

    reconfigure(
      with: ConfigurationOptions(
        css: css,
        plugins: plugins,
        stylesheets: stylesheets,
        styled: styled
      )
    )
    render(markdown: markdown, options: RenderOptions(enableImage: enableImage))
  }

  @available(*, deprecated, message: "Use render(markdown:options:) instead.")
  public func show(markdown: String) {
    render(markdown: markdown)
  }

  public func render(markdown: String, options: RenderOptions = RenderOptions()) {
    renderMarkdown(markdown: markdown, enableImage: options.enableImage)
  }

  @objc public func reconfigure(css: String? = nil,
                                plugins: [String]? = nil,
                                stylesheets: [URL]? = nil,
                                styled: Bool = true) {
    reconfigure(
      with: ConfigurationOptions(
        css: css,
        plugins: plugins,
        stylesheets: stylesheets,
        styled: styled
      )
    )
  }

  public func reconfigure(with options: ConfigurationOptions) {
    configureWebView(
      with: MarkdownRenderingConfiguration(
        css: options.css,
        plugins: options.plugins,
        stylesheets: options.stylesheets
      ),
      styled: options.styled
    )
  }

  private func renderMarkdown(markdown: String, enableImage: Bool) {
    guard let webView else { return }

    guard isWebViewLoaded else {
      pendingRenderRequest = PendingRenderRequest(markdown: markdown, enableImage: enableImage)
      return
    }

    let payload: [String: Any] = [
      "markdown": markdown,
      "enableImage": enableImage
    ]
    webView.callAsyncJavaScript(
      "window.renderMarkdown(payload)",
      arguments: ["payload": payload],
      in: nil,
      in: .page
    ) { result in
      guard case let .failure(error) = result else { return }
      print("[MarkdownView][Error] Failed to call window.renderMarkdown: \(error)")
    }
  }
}

// MARK: - WKNavigationDelegate

extension MarkdownView: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    isWebViewLoaded = true

    if let request = pendingRenderRequest {
      pendingRenderRequest = nil
      renderMarkdown(markdown: request.markdown, enableImage: request.enableImage)
    }
  }

  public func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    switch navigationAction.navigationType {
    case .linkActivated:
      if let onTouchLink, onTouchLink(navigationAction.request) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    default:
      decisionHandler(.allow)
    }
  }
}

private extension MarkdownView {
  static var styledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(forResource: "styled",
                      withExtension: "html") ??
      bundle.url(forResource: "styled",
                 withExtension: "html",
                 subdirectory: "MarkdownView.bundle")!
  }()

  static var nonStyledHtmlUrl: URL = {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle(for: MarkdownView.self)
    #endif
    return bundle.url(forResource: "non_styled",
                      withExtension: "html") ??
      bundle.url(forResource: "non_styled",
                 withExtension: "html",
                 subdirectory: "MarkdownView.bundle")!
  }()

  func setupEventBridge() {
    eventBridge = MarkdownEventBridge { [weak self] height in
      guard let self else { return }

      if let currentHeight = self.intrinsicContentHeight,
         abs(height - currentHeight) < Self.minimumHeightDeltaToNotify {
        return
      }

      self.onRendered?(height)
      self.intrinsicContentHeight = height
    }
  }

  func configureWebView(with renderingConfiguration: MarkdownRenderingConfiguration, styled: Bool) {
    webView?.removeFromSuperview()
    isWebViewLoaded = false
    pendingRenderRequest = nil

    let configuration = WKWebViewConfiguration()
    let contentController = scriptBuilder.makeContentController(configuration: renderingConfiguration)
    eventBridge?.attach(to: contentController)
    configuration.userContentController = contentController

    webView = webViewFactory.makeWebView(
      with: configuration,
      in: self,
      scrollEnabled: isScrollEnabled,
      navigationDelegate: self
    )
    webView?.load(URLRequest(url: styled ? Self.styledHtmlUrl : Self.nonStyledHtmlUrl))
  }
}
