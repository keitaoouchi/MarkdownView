import SwiftUI
import WebKit // Added as MarkdownView uses it, good for context.

@MainActor
public struct MarkdownUI: UIViewRepresentable {
    // MARK: - Properties
    
    @Binding private var body: String
    private var css: String?
    private var plugins: [String]?
    private var stylesheets: [URL]?
    private var styled: Bool
    
    // Callbacks
    private var onTouchLinkHandler: (@MainActor (URLRequest) -> Bool)?
    private var onRenderedHandler: (@MainActor (CGFloat) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        body: Binding<String>,
        css: String? = nil,
        plugins: [String]? = nil,
        stylesheets: [URL]? = nil,
        styled: Bool = true
    ) {
        self._body = body
        self.css = css
        self.plugins = plugins
        self.stylesheets = stylesheets
        self.styled = styled
    }
    
    // MARK: - Modifiers
    
    public func onTouchLink(
        perform action: @escaping @MainActor (URLRequest) -> Bool
    ) -> MarkdownUI {
        var view = self
        view.onTouchLinkHandler = action
        return view
    }
    
    public func onRendered(
        perform action: @escaping @MainActor (CGFloat) -> Void
    ) -> MarkdownUI {
        var view = self
        view.onRenderedHandler = action
        return view
    }
    
    // MARK: - UIViewRepresentable
    
    public func makeUIView(context: Context) -> MarkdownView {
        let markdownView = MarkdownView( // This will use the convenience init that now internally uses a Task for setupWebView
            css: css,
            plugins: plugins,
            stylesheets: stylesheets,
            styled: styled
        )
        
        markdownView.isScrollEnabled = false // As per issue
        markdownView.onTouchLink = onTouchLinkHandler
        markdownView.onRendered = onRenderedHandler
        
        // Initial load when view is created
        // updateUIView will handle subsequent updates
        // Ensure this task also runs on the main actor, as it involves UI setup.
        Task { @MainActor in
            await markdownView.show(markdown: body)
        }
        
        return markdownView
    }
    
    public func updateUIView(_ uiView: MarkdownView, context: Context) {
        // Check if the markdown content has actually changed before triggering a reload.
        // This simple check might need to be more sophisticated based on real-world usage
        // (e.g., comparing old vs new values from context if available and relevant).
        // For now, we assume 'body' binding changes mean a reload is needed.
        
        Task { @MainActor in // Ensure UI updates are on the main actor
            await uiView.show(markdown: body)
        }
    }
    
    public static func dismantleUIView(_ uiView: MarkdownView, coordinator: ()) {
        // Cleanup if necessary, e.g., stop loading, remove from hierarchy if not done automatically
        uiView.webView?.stopLoading()
    }
    
    // Coordinator can be used for delegate patterns if needed in the future
    public func makeCoordinator() -> () {
        // Empty coordinator for now
        return ()
    }
}
