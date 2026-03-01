import UIKit
import WebKit

/// Manages a pool of pre-loaded WKWebView instances for fast dequeue.
///
/// Pre-warmed WebViews have the HTML template (with inlined JS/CSS) already loaded,
/// eliminating the 50-100+ ms WKWebView init and 200-400 ms first page load.
///
/// Usage:
/// ```swift
/// // In AppDelegate.didFinishLaunching or early in the app lifecycle:
/// MarkdownWebViewPool.shared.warmUp(count: 2)
/// ```
public final class MarkdownWebViewPool: @unchecked Sendable {
    public static let shared = MarkdownWebViewPool()

    private struct PoolEntry {
        let webView: WKWebView
        var isLoaded: Bool
    }

    private var styledPool: [PoolEntry] = []
    private var nonStyledPool: [PoolEntry] = []
    private let maxPoolSize: Int
    private let lock = NSLock()

    public init(maxPoolSize: Int = 3) {
        self.maxPoolSize = maxPoolSize

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Pre-warm pool entries. Call early (e.g., in AppDelegate.didFinishLaunching).
    public func warmUp(count: Int = 2, styled: Bool = true) {
        guard count > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for _ in 0..<min(count, self.maxPoolSize) {
                self.createAndEnpool(styled: styled)
            }
        }
    }

    /// Dequeue a pre-warmed, fully loaded WebView. Returns nil if pool is empty.
    func dequeue(styled: Bool) -> WKWebView? {
        lock.lock()
        defer { lock.unlock() }

        let pool = styled ? styledPool : nonStyledPool
        guard let index = pool.firstIndex(where: { $0.isLoaded }) else { return nil }

        let entry = pool[index]
        if styled {
            styledPool.remove(at: index)
        } else {
            nonStyledPool.remove(at: index)
        }

        // Schedule refill
        DispatchQueue.main.async { [weak self] in
            self?.createAndEnpool(styled: styled)
        }

        return entry.webView
    }

    @objc private func handleMemoryWarning() {
        lock.lock()
        styledPool.removeAll()
        nonStyledPool.removeAll()
        lock.unlock()
    }

    private func createAndEnpool(styled: Bool) {
        lock.lock()
        let currentCount = styled ? styledPool.count : nonStyledPool.count
        guard currentCount < maxPoolSize else {
            lock.unlock()
            return
        }
        lock.unlock()

        let configuration = WKWebViewConfiguration()
        configuration.processPool = MarkdownView.sharedProcessPool

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let htmlString = styled ? MarkdownView.styledHtmlString : MarkdownView.nonStyledHtmlString

        let tracker = PoolLoadTracker { [weak self, weak webView] in
            guard let self, let webView else { return }
            self.lock.lock()
            if styled {
                if let idx = self.styledPool.firstIndex(where: { $0.webView === webView }) {
                    self.styledPool[idx].isLoaded = true
                }
            } else {
                if let idx = self.nonStyledPool.firstIndex(where: { $0.webView === webView }) {
                    self.nonStyledPool[idx].isLoaded = true
                }
            }
            self.lock.unlock()
        }
        webView.navigationDelegate = tracker
        objc_setAssociatedObject(webView, &PoolLoadTracker.associatedKey, tracker, .OBJC_ASSOCIATION_RETAIN)

        lock.lock()
        if styled {
            styledPool.append(PoolEntry(webView: webView, isLoaded: false))
        } else {
            nonStyledPool.append(PoolEntry(webView: webView, isLoaded: false))
        }
        lock.unlock()

        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

private class PoolLoadTracker: NSObject, WKNavigationDelegate {
    nonisolated(unsafe) static var associatedKey: UInt8 = 0
    let onLoaded: () -> Void

    init(onLoaded: @escaping () -> Void) {
        self.onLoaded = onLoaded
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoaded()
    }
}
