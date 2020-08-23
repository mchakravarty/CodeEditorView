import XCTest
@testable import CodeEditor

final class CodeEditorTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CodeEditor().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
