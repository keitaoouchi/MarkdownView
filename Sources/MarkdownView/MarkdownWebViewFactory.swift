import UIKit
import WebKit

struct MarkdownWebViewFactory {
    func makeWebView(with configuration: WKWebViewConfiguration,
                     in containerView: UIView,
                     scrollEnabled: Bool,
                     navigationDelegate: WKNavigationDelegate) -> WKWebView {
        let webView = WKWebView(frame: containerView.bounds, configuration: configuration)
        webView.scrollView.isScrollEnabled = scrollEnabled
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = navigationDelegate
        containerView.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        return webView
    }
}
