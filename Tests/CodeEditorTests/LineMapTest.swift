import XCTest
@testable import CodeEditorView

func mkRange(loc: Int, len: Int) -> LineMap<Void>.OneLine {
  return (range: NSRange(location: loc, length: len), info: nil)
}

final class LineMapTests: XCTestCase {

  // Initialisation tests

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


  // Lookup tests

  func testLookupEmpty() {
    XCTAssertNil(LineMap<Void>(string: "").lineContaining(index: 0))
  }

  func testLookupLineBreak() {
    let lineMap = LineMap<Void>(string: "\n")
    XCTAssertNil(lineMap.lineContaining(index: 1))
    XCTAssertEqual(lineMap.lineContaining(index: 0), 1)
  }

  func testLookupSimple() {
    let lineMap = LineMap<Void>(string: "abc")
    XCTAssertNil(lineMap.lineContaining(index: 3))
    XCTAssertEqual(lineMap.lineContaining(index: 0), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 2), 1)
  }

  func testLookupEmptyTrailing() {
    let lineMap = LineMap<Void>(string: "abc\n")
    XCTAssertNil(lineMap.lineContaining(index: 4))
    XCTAssertEqual(lineMap.lineContaining(index: 0), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 2), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 3), 1)
  }

  func testLookupLines() {
    let lineMap = LineMap<Void>(string: "abc\ndefg\nhij")
    XCTAssertEqual(lineMap.lineContaining(index: 0), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 3), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 4), 2)
    XCTAssertEqual(lineMap.lineContaining(index: 9), 3)
  }

  func testLookupEmptyLines() {
    let lineMap = LineMap<Void>(string: "\nabc\n\n\ndefg\nhi\n")
    XCTAssertEqual(lineMap.lineContaining(index: 0), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 4), 2)
    XCTAssertEqual(lineMap.lineContaining(index: 5), 3)
    XCTAssertEqual(lineMap.lineContaining(index: 11), 5)
    XCTAssertEqual(lineMap.lineContaining(index: 14), 6)
  }

  static var allTests = [
    ("testInitEmpty", testInitEmpty),
    ("testInitLineBreak", testInitLineBreak),
    ("testInitSimple", testInitSimple),
    ("testInitEmptyTrailing", testInitEmptyTrailing),
    ("testInitLines", testInitLines),
    ("testInitEmptyLines", testInitEmptyLines),

    ("textLookupEmpty", testLookupEmpty),
  ]
}
