import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
  return [
    testCase(LineMapTests.allTests),
    testCase(CodeEditorTests.allTests),
  ]
}
#endif
