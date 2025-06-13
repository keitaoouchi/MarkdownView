import XCTest
import SwiftUI // For MarkdownUI and Binding
@testable import MarkdownView // To access MarkdownView and MarkdownUI

@MainActor
final class MarkdownViewTests: XCTestCase {

    // MARK: - Initialization Tests

    func testMarkdownViewInitialization() {
        let markdownView = MarkdownView()
        XCTAssertNotNil(markdownView, "MarkdownView should initialize successfully.")
    }

    func testMarkdownUIInitialization() {
        let bodyBinding = Binding.constant("# Hello")
        let markdownUI = MarkdownUI(body: bodyBinding)
        XCTAssertNotNil(markdownUI, "MarkdownUI should initialize successfully.")
        // Check if the underlying view is created, makeUIView is implicitly tested by SwiftUI
    }

    // MARK: - Content Loading & onRendered Callback Tests

    func testMarkdownViewLoad() async throws {
        let markdownView = MarkdownView()
        let expectation = XCTestExpectation(description: "onRendered callback for load")
        var renderedHeight: CGFloat = 0

        markdownView.onRendered = { height in
            renderedHeight = height
            expectation.fulfill()
        }

        // The load method is now async and handles its own webview setup
        await markdownView.load(markdown: "# Test Header")
        
        wait(for: [expectation], timeout: 10.0) // Wait for onRendered
        XCTAssertGreaterThan(renderedHeight, 0, "Rendered height should be greater than 0 after loading content.")
    }

    func testMarkdownViewShow() async throws {
        // Initialize MarkdownView with pre-loaded webView (styled=true is default)
        // This convenience init calls setupWebView which is async
        let markdownView = MarkdownView(css: nil, plugins: nil, stylesheets: nil, styled: true)
        
        // Wait for the initial setupWebView to complete if it's still running from init.
        // A short delay or a more sophisticated readiness check might be needed if init's Task is slow.
        // For now, assuming init's webview setup is reasonably fast or relying on `show` to manage.
        
        let expectation = XCTestExpectation(description: "onRendered callback for show")
        var renderedHeight: CGFloat = 0

        markdownView.onRendered = { height in
            renderedHeight = height
            expectation.fulfill()
        }
        
        // Wait until the webView is ready instead of sleeping for a fixed time
        var attempts = 0
        while markdownView.webView == nil && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            attempts += 1
        }
        XCTAssertNotNil(markdownView.webView, "WebView should be initialized before calling show")

        await markdownView.show(markdown: "## Another Test Header")
        
        wait(for: [expectation], timeout: 10.0) // Wait for onRendered
        XCTAssertGreaterThan(renderedHeight, 0, "Rendered height should be greater than 0 after showing content.")
    }
    
    // MARK: - SwiftUI MarkdownUI Update Test
    // This test is more complex and might require UI testing capabilities or a different approach.
    // For now, we'll focus on the direct `MarkdownView` tests.
    // A basic conceptual test:
    func testMarkdownUIBodyUpdate() async throws {
        let initialBody = "# Initial"
        let updatedBody = "## Updated"
        var bodyBinding = Binding.constant(initialBody)
        
        let markdownUI = MarkdownUI(body: bodyBinding)
        
        // Simulate creating the view (as SwiftUI would)
        let uiView = markdownUI.makeUIView(context: UIViewRepresentableContext<MarkdownUI>())
        
        let expectationRenderInitial = XCTestExpectation(description: "onRendered for initial body in MarkdownUI")
        uiView.onRendered = { height in
            if height > 0 { // Ensure it's a valid render
                expectationRenderInitial.fulfill()
            }
        }
        // `makeUIView` now calls `show` internally.
        wait(for: [expectationRenderInitial], timeout: 10.0)
        
        // Now update the binding and simulate SwiftUI calling updateUIView
        bodyBinding.wrappedValue = updatedBody
        
        let expectationRenderUpdate = XCTestExpectation(description: "onRendered for updated body in MarkdownUI")
        uiView.onRendered = { height in
            if height > 0 { // Ensure it's a valid render
                 expectationRenderUpdate.fulfill()
            }
        }
        
        // Manually call updateUIView
        markdownUI.updateUIView(uiView, context: UIViewRepresentableContext<MarkdownUI>())
        
        wait(for: [expectationRenderUpdate], timeout: 10.0)
        // A more robust test would inspect the webView content if possible,
        // but checking onRendered is a good proxy for the update triggering a reload.
    }

    // onTouchLink is difficult to test in a pure unit test environment
    // as it requires user interaction or complex WKNavigationDelegate mocking.
}
