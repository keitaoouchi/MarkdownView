import XCTest
@testable import MarkdownView

final class MarkdownViewTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MarkdownView().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
