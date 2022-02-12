import SwiftUI

public final class MarkdownUI: UIViewRepresentable {
  private let markdownView: MarkdownView
  
  @Binding public var body: String
  
  public init(body: String? = nil, css: String? = nil, plugins: [String]? = nil, stylesheets: [URL]? = nil, styled: Bool = true) {
    self._body = .constant(body ?? "")
    self.markdownView = MarkdownView(css: css, plugins: plugins, stylesheets: stylesheets, styled: styled)
    self.markdownView.isScrollEnabled = false
    
    self.markdownView.onRendered = { height in
      print(height)
      
    }
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
