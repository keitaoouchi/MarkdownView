import SwiftUI

public struct MarkdownUI: UIViewRepresentable {
  @Binding public var body: String

  private let css: String?
  private let plugins: [String]?
  private let stylesheets: [URL]?
  private let styled: Bool
  private var onTouchLinkHandler: ((URLRequest) -> Bool)?
  private var onRenderedHandler: ((CGFloat) -> Void)?

  public init(body: String? = nil, css: String? = nil, plugins: [String]? = nil, stylesheets: [URL]? = nil, styled: Bool = true) {
    self._body = .constant(body ?? "")
    self.css = css
    self.plugins = plugins
    self.stylesheets = stylesheets
    self.styled = styled
  }

  public func onTouchLink(perform action: @escaping ((URLRequest) -> Bool)) -> MarkdownUI {
    var copy = self
    copy.onTouchLinkHandler = action
    return copy
  }

  public func onRendered(perform action: @escaping ((CGFloat) -> Void)) -> MarkdownUI {
    var copy = self
    copy.onRenderedHandler = action
    return copy
  }

  public func makeUIView(context: Context) -> MarkdownView {
    let view = MarkdownView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
    view.isScrollEnabled = false
    view.onTouchLink = onTouchLinkHandler
    view.onRendered = onRenderedHandler
    return view
  }

  public func updateUIView(_ uiView: MarkdownView, context: Context) {
    uiView.onTouchLink = onTouchLinkHandler
    uiView.onRendered = onRenderedHandler
    uiView.show(markdown: body)
  }
}
