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

    private var currentRenderingConfiguration: MarkdownRenderingConfiguration?
    private var currentStyledFlag: Bool = true
    private var hasInjectedExtendedLanguages = false

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
        guard webView != nil else { return }

        guard isWebViewLoaded else {
            // B-5: Instead of queuing a pendingRenderRequest, restart the load
            // with markdown embedded in the HTML template. This eliminates the
            // didFinish → callAsyncJavaScript round-trip for the first render.
            if let config = currentRenderingConfiguration {
                configureWebView(
                    with: config,
                    styled: currentStyledFlag,
                    initialMarkdown: markdown,
                    enableImage: enableImage
                )
            } else {
                pendingRenderRequest = PendingRenderRequest(markdown: markdown, enableImage: enableImage)
            }
            return
        }

        let payload: [String: Any] = [
            "markdown": markdown,
            "enableImage": enableImage
        ]
        webView?.callAsyncJavaScript(
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

        // B-3: After initial page load, inject full highlight.js bundle
        // to support all 113 languages (core bundle only has 15)
        injectExtendedLanguagesIfNeeded()
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

// MARK: - Resources

extension MarkdownView {
    static let styledHtmlString: String = loadResource(name: "styled", ext: "html")
    static let nonStyledHtmlString: String = loadResource(name: "non_styled", ext: "html")
    static let extendedLanguagesJs: String = loadResource(name: "main", ext: "js")

    static func loadResource(name: String, ext: String) -> String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: MarkdownView.self)
        #endif
        let url = bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "MarkdownView.bundle")!
        return (try? String(contentsOf: url)) ?? ""
    }
}

private extension MarkdownView {

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

    func configureWebView(with renderingConfiguration: MarkdownRenderingConfiguration,
                          styled: Bool,
                          initialMarkdown: String? = nil,
                          enableImage: Bool = true) {
        webView?.removeFromSuperview()
        isWebViewLoaded = false
        pendingRenderRequest = nil
        hasInjectedExtendedLanguages = false
        currentRenderingConfiguration = renderingConfiguration
        currentStyledFlag = styled

        // B-2: Try to dequeue a pre-warmed WebView from the pool
        if let pooledWebView = MarkdownWebViewPool.shared.dequeue(styled: styled) {
            pooledWebView.translatesAutoresizingMaskIntoConstraints = false
            pooledWebView.navigationDelegate = self
            pooledWebView.scrollView.isScrollEnabled = isScrollEnabled
            addSubview(pooledWebView)
            NSLayoutConstraint.activate([
                pooledWebView.topAnchor.constraint(equalTo: topAnchor),
                pooledWebView.bottomAnchor.constraint(equalTo: bottomAnchor),
                pooledWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
                pooledWebView.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            webView = pooledWebView

            // Inject CSS/plugins via evaluateJavaScript (since pooled WebViews use default config)
            let scripts = scriptBuilder.makeScriptStrings(configuration: renderingConfiguration)
            for script in scripts {
                pooledWebView.evaluateJavaScript(script, completionHandler: nil)
            }

            // Attach event bridge to pooled WebView's content controller
            eventBridge?.attach(to: pooledWebView.configuration.userContentController)

            isWebViewLoaded = true

            // If initial markdown is provided, render immediately
            if let initialMarkdown {
                renderMarkdown(markdown: initialMarkdown, enableImage: enableImage)
            }
            return
        }

        // Standard path: create a new WebView
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

        let baseHtml = styled ? Self.styledHtmlString : Self.nonStyledHtmlString

        if let initialMarkdown {
            let htmlString = Self.embedMarkdown(in: baseHtml, markdown: initialMarkdown, enableImage: enableImage)
            webView?.loadHTMLString(htmlString, baseURL: nil)
        } else {
            webView?.loadHTMLString(baseHtml, baseURL: nil)
        }
    }

    func injectExtendedLanguagesIfNeeded() {
        guard !hasInjectedExtendedLanguages, let webView else { return }
        hasInjectedExtendedLanguages = true

        let fullJs = Self.extendedLanguagesJs
        guard !fullJs.isEmpty else { return }

        // Inject the full bundle (re-registers all 113 languages on the shared hljs instance)
        // then re-highlight any code blocks that may have been rendered with core-only languages
        let script = fullJs + """
        ; document.querySelectorAll('pre code').forEach(function(block) {
            block.removeAttribute('data-highlighted');
            hljs.highlightElement(block);
        });
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                print("[MarkdownView] Extended languages injection failed: \(error)")
            }
        }
    }

    static func embedMarkdown(in html: String, markdown: String, enableImage: Bool) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let initScript = """
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            window.renderMarkdown({ markdown: `\(escaped)`, enableImage: \(enableImage) });
        });
        </script>
        """

        return html.replacingOccurrences(of: "</body>", with: "\(initScript)\n</body>")
    }
}
