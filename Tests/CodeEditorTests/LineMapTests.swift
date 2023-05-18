import XCTest
@testable import CodeEditorView

func mkRange(loc: Int, len: Int) -> LineMap<Void>.OneLine {
  return (range: NSRange(location: loc, length: len), info: nil)
}

final class LineMapTests: XCTestCase {

  // Initialisation tests

  func hasLineMap(_ string: String, _ lineMap: LineMap<Void>) {
    let computedLineMap = LineMap<Void>(string: string)
    XCTAssertEqual(computedLineMap.lines.map{ $0.range }, lineMap.lines.map{ $0.range })
  }

  func testInitEmpty() {
    hasLineMap("",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 0)]))
  }

  func testInitLineBreak() {
    hasLineMap("\n",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 1), mkRange(loc: 1, len: 0)]))
  }

  func testInitSimple() {
    hasLineMap("abc",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 3)]))
  }

  func testInitSimpleTrailing() {
    hasLineMap("abc\n",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 4), mkRange(loc: 4, len: 0)]))
  }

  func testInitLines() {
    hasLineMap("abc\ndefg\nhij",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 4),
                                     mkRange(loc: 4, len: 5),
                                     mkRange(loc: 9, len: 3)]))
  }

  func testInitEmptyLines() {
    hasLineMap("\nabc\n\n\ndefg\nhi\n",
               LineMap<Void>(lines: [mkRange(loc: 0, len: 1),
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
    XCTAssertEqual(lineMap.lineContaining(index: 0), 0)
  }

  func testLookupSimple() {
    let lineMap = LineMap<Void>(string: "abc")
    XCTAssertNil(lineMap.lineContaining(index: 3))
    XCTAssertEqual(lineMap.lineContaining(index: 0), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 2), 0)
  }

  func testLookupSimpleTrailing() {
    let lineMap = LineMap<Void>(string: "abc\n")
    XCTAssertNil(lineMap.lineContaining(index: 4))
    XCTAssertEqual(lineMap.lineContaining(index: 0), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 2), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 3), 0)
  }

  func testLookupLines() {
    let lineMap = LineMap<Void>(string: "abc\ndefg\nhij")
    XCTAssertEqual(lineMap.lineContaining(index: 0), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 3), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 4), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 9), 2)
  }

  func testLookupEmptyLines() {
    let lineMap = LineMap<Void>(string: "\nabc\n\n\ndefg\nhi\n")
    XCTAssertEqual(lineMap.lineContaining(index: 0), 0)
    XCTAssertEqual(lineMap.lineContaining(index: 4), 1)
    XCTAssertEqual(lineMap.lineContaining(index: 5), 2)
    XCTAssertEqual(lineMap.lineContaining(index: 11), 4)
    XCTAssertEqual(lineMap.lineContaining(index: 14), 5)
  }

  // Editing tests

  func testEditing(string: String, into newString: String, range: NSRange, changeInLength: Int) {
    var lineMap = LineMap<Void>(string: string)
    lineMap.updateAfterEditing(string: newString, range: range, changeInLength: changeInLength)
    hasLineMap(newString, lineMap)
  }

  func testEditingEmpty() {
    let string = ""
    testEditing(string: string, into: "abc", range: NSRange(location: 0, length: 3), changeInLength: 3)
    testEditing(string: string, into: "abc\n", range: NSRange(location: 0, length: 4), changeInLength: 4)
  }

  func testEditingLineBreak() {
    let string = "\n"
    testEditing(string: string, into: "abc", range: NSRange(location: 0, length: 3), changeInLength: 2)
    testEditing(string: string, into: "abc\n", range: NSRange(location: 0, length: 3), changeInLength: 3)
    testEditing(string: string, into: "\nabc", range: NSRange(location: 1, length: 3), changeInLength: 3)
    testEditing(string: string, into: "\n\n", range: NSRange(location: 0, length: 1), changeInLength: 1)

    testEditing(string: string, into: "x", range: NSRange(location: 0, length: 1), changeInLength: 0)

    testEditing(string: string, into: "", range: NSRange(location: 0, length: 0), changeInLength: -1)
  }

  func testEditingSimple() {
    let string = "abc"
    testEditing(string: string, into: "abc", range: NSRange(location: 1, length: 0), changeInLength: 0)
    testEditing(string: string, into: "abc\n", range: NSRange(location: 3, length: 1), changeInLength: 1)
    testEditing(string: string, into: "\nabc", range: NSRange(location: 0, length: 1), changeInLength: 1)
    testEditing(string: string, into: "ab\nc", range: NSRange(location: 2, length: 1), changeInLength: 1)
    testEditing(string: string, into: "ab\n\n\nc", range: NSRange(location: 2, length: 3), changeInLength: 3)

    testEditing(string: string, into: "ac", range: NSRange(location: 1, length: 0), changeInLength: -1)
  }

  func testEditingSimpleTrailing() {
    let string = "abc\n"
    testEditing(string: string, into: "abc\n\n\n", range: NSRange(location: 4, length: 2), changeInLength: 2)
    testEditing(string: string, into: "abc\n\n", range: NSRange(location: 3, length: 1), changeInLength: 1)
    testEditing(string: string, into: "ab\n\n\nc\n", range: NSRange(location: 2, length: 3), changeInLength: 3)

    testEditing(string: string, into: "abcx", range: NSRange(location: 3, length: 1), changeInLength: 0)

    testEditing(string: string, into: "abc", range: NSRange(location: 3, length: 0), changeInLength: -1)
  }

  func testEditingEmptyLines() {
    let string = "\nabc\n\n\ndefg\nhi\n"
    testEditing(string: string, into: "x\nabc\n\n\ndefg\nhi\n", range: NSRange(location: 0, length: 1), changeInLength: 1)
    testEditing(string: string, into: "\nxabc\n\n\ndefg\nhi\n", range: NSRange(location: 1, length: 1), changeInLength: 1)
    testEditing(string: string, into: "\nabcx\n\n\ndefg\nhi\n", range: NSRange(location: 4, length: 1), changeInLength: 1)
    testEditing(string: string, into: "\nabc\nx\n\ndefg\nhi\n", range: NSRange(location: 5, length: 1), changeInLength: 1)

    testEditing(string: string, into: "\nabc\n\n\ndefg\nhix", range: NSRange(location: 14, length: 1), changeInLength: 0)
    testEditing(string: string, into: "\nabc\nx\ndefg\nhi\n", range: NSRange(location: 5, length: 1), changeInLength: 0)

    testEditing(string: string, into: "\nabc\n\ndefg\nhi\n", range: NSRange(location: 5, length: 0), changeInLength: -1)
    testEditing(string: string, into: "\nabc\n\ndefg\nhi\n", range: NSRange(location: 6, length: 0), changeInLength: -1)
    testEditing(string: string, into: "\nabcdefg\nhi\n", range: NSRange(location: 4, length: 0), changeInLength: -3)
    testEditing(string: string, into: "abc\n\n\ndefg\nhi\n", range: NSRange(location: 0, length: 0), changeInLength: -1)
  }

// Doesn't seem useful as we cannot easily harden against all such inconsistent invocations.
//  func testEditingBogus() {
//    let string = "\nabc\n\n\ndefg\nhi\n"
//
//    testEditing(string: string, into: "\nabc\nx\ndefg\nhi\n", range: NSRange(location: 5, length: 1), changeInLength: -100)
//    testEditing(string: string, into: "\nabc\nx\ndefg\nhi\n", range: NSRange(location: 5, length: 1), changeInLength: 10)
//    testEditing(string: string, into: "\nabc\nx\ndefg\nhi\n", range: NSRange(location: 5, length: 20), changeInLength: 10)
//  }

  static var allTests = [
    ("testInitEmpty", testInitEmpty),
    ("testInitLineBreak", testInitLineBreak),
    ("testInitSimple", testInitSimple),
    ("testInitEmptyTrailing", testInitSimpleTrailing),
    ("testInitLines", testInitLines),
    ("testInitEmptyLines", testInitEmptyLines),

    ("testLookupEmpty", testLookupEmpty),
    ("testLookupLineBreak", testLookupLineBreak),
    ("testLookupSimple", testLookupSimple),
    ("testLookupEmptyTrailing", testLookupSimpleTrailing),
    ("testLookupLines", testLookupLines),
    ("testLookupEmptyLines", testLookupEmptyLines),

    ("testEditingEmpty", testEditingEmpty),
    ("testEditingLineBreak", testEditingLineBreak),
    ("testEditingSimple", testEditingSimple),
    ("testEditingSimpleTrailing", testEditingSimpleTrailing),
    ("testEditingEmptyLines", testEditingEmptyLines),

//    ("testEditingBogus", testEditingBogus),
  ]
}
