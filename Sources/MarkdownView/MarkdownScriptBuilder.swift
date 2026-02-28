import Foundation
import WebKit

struct MarkdownScriptBuilder {
  func makeContentController(configuration: MarkdownRenderingConfiguration) -> WKUserContentController {
    let controller = WKUserContentController()

    if let css = configuration.css {
      controller.addUserScript(
        WKUserScript(source: styleScript(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      )
    }

    configuration.plugins?.forEach { plugin in
      controller.addUserScript(
        WKUserScript(source: usePluginScript(plugin), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      )
    }

    configuration.stylesheets?.forEach { url in
      controller.addUserScript(
        WKUserScript(source: linkScript(url), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      )
    }

    return controller
  }

  private func styleScript(_ css: String) -> String {
    [
      "var s = document.createElement('style');",
      "s.innerHTML = `\(css)`;",
      "document.head.appendChild(s);"
    ].joined()
  }

  private func linkScript(_ url: URL) -> String {
    [
      "var link = document.createElement('link');",
      "link.href = '\(url.absoluteURL)';",
      "link.rel = 'stylesheet';",
      "document.head.appendChild(link);"
    ].joined()
  }

  private func usePluginScript(_ pluginBody: String) -> String {
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

struct MarkdownRenderingConfiguration {
  let css: String?
  let plugins: [String]?
  let stylesheets: [URL]?

}
