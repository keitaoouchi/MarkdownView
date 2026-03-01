import MarkdownView
import SnapshotTesting
import SwiftUI
import XCTest

@testable import Example

final class ExampleSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
//        isRecording = true
    }

    func testCodeOnlySample() {
        let vc = CodeOnlySampleViewController()
        waitForRendering(of: vc)
        assertSnapshot(of: vc, as: .image(on: .iPhone17Pro))
    }

    func testCustomCssSample() {
        let vc = CustomCssSampleViewController()
        waitForRendering(of: vc)
        assertSnapshot(of: vc, as: .image(on: .iPhone17Pro))
    }

    func testSampleUI() {
        let vc = UIHostingController(rootView: SampleUI())
        waitForRendering(of: vc)
        assertSnapshot(of: vc, as: .image(on: .iPhone17Pro))
    }
}

// MARK: - Helpers

private extension ExampleSnapshotTests {

    func waitForRendering(of viewController: UIViewController, timeout: TimeInterval = 10) {
        let size = CGSize(width: 402, height: 874)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        guard let mdView = findMarkdownView(in: viewController.view) else {
            XCTFail("MarkdownView not found in view hierarchy")
            return
        }

        let rendered = expectation(description: "Markdown rendered")
        rendered.assertForOverFulfill = false
        let original = mdView.onRendered
        mdView.onRendered = { height in
            original?(height)
            rendered.fulfill()
        }

        wait(for: [rendered], timeout: timeout)

        // WKWebView composites pixels asynchronously after DOM measurement.
        // Give the render process time to paint.
        let composited = expectation(description: "Compositing")
        composited.isInverted = true
        wait(for: [composited], timeout: 1.0)

        window.isHidden = true
    }

    func findMarkdownView(in view: UIView) -> MarkdownView? {
        if let md = view as? MarkdownView { return md }
        for subview in view.subviews {
            if let found = findMarkdownView(in: subview) { return found }
        }
        return nil
    }
}

private extension ViewImageConfig {
    static let iPhone17Pro = ViewImageConfig(
        safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        size: CGSize(width: 402, height: 874),
        traits: UITraitCollection(traitsFrom: [
            .init(forceTouchCapability: .unavailable),
            .init(layoutDirection: .leftToRight),
            .init(preferredContentSizeCategory: .medium),
            .init(userInterfaceIdiom: .phone),
        ])
    )
}
