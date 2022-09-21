import SwiftUI

public struct MarkdownUI: UIViewRepresentable {
  private let markdownView: MarkdownView
  
  @Binding public var body: String
  
  public init(body: String? = nil, css: String? = nil, plugins: [String]? = nil, stylesheets: [URL]? = nil, styled: Bool = true) {
    self._body = .constant(body ?? "")
    self.markdownView = MarkdownView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
    self.markdownView.isScrollEnabled = false
  }
  
  public func onTouchLink(perform action: @escaping ((URLRequest) -> Bool)) -> MarkdownUI {
    self.markdownView.onTouchLink = action
    return self
  }
  
  public func onRendered(perform action: @escaping ((CGFloat) -> Void)) -> MarkdownUI {
    self.markdownView.onRendered = action
    return self
  }
}

extension MarkdownUI {
  
  public func makeUIView(context: Context) -> MarkdownView {
    return markdownView
  }
  
  public func updateUIView(_ uiView: MarkdownView, context: Context) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.markdownView.show(markdown: self.body)
    }
  }
  
  public func makeCoordinator() -> () {
    
  }
}
