import XCTest
@testable import CodeEditorView

func mkRange(loc: Int, len: Int) -> LineMap<Void>.OneLine {
  return (range: NSRange(location: loc, length: len), info: nil)
}

final class LineMapTests: XCTestCase {

  func testInit(_ string: String, _ lineMap: LineMap<Void>) {
    let computedLineMap = LineMap<Void>(string: string)
    XCTAssertEqual(computedLineMap.lines.map{ $0.range }, lineMap.lines.map{ $0.range })
  }

  func testInitEmpty() {
    testInit("",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0), mkRange(loc: 0, len: 0)]))
  }

  func testInitLineBreak() {
    testInit("\n",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0), mkRange(loc: 0, len: 1), mkRange(loc: 1, len: 0)]))
  }

  func testInitSimple() {
    testInit("abc",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0), mkRange(loc: 0, len: 3)]))
  }

  func testInitEmptyTrailing() {
    testInit("abc\n",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0), mkRange(loc: 0, len: 4), mkRange(loc: 4, len: 0)]))
  }

  func testInitLines() {
    testInit("abc\ndefg\nhij",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0),
                                   mkRange(loc: 0, len: 4),
                                   mkRange(loc: 4, len: 5),
                                   mkRange(loc: 9, len: 3)]))
  }

  func testInitEmptyLines() {
    testInit("\nabc\n\n\ndefg\nhi\n",
             LineMap<Void>(lines: [mkRange(loc: 0, len: 0),
                                   mkRange(loc: 0, len: 1),
                                   mkRange(loc: 1, len: 4),
                                   mkRange(loc: 5, len: 1),
                                   mkRange(loc: 6, len: 1),
                                   mkRange(loc: 7, len: 5),
                                   mkRange(loc: 12, len: 3),
                                   mkRange(loc: 15, len: 0)]))
  }

  static var allTests = [
    ("testInitEmpty", testInitEmpty),
    ("testInitLineBreak", testInitLineBreak),
    ("testInitSimple", testInitSimple),
    ("testInitEmptyTrailing", testInitEmptyTrailing),
    ("testInitLines", testInitLines),
    ("testInitEmptyLines", testInitEmptyLines),
  ]
}
