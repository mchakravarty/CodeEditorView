//
//  TokenTests.swift
//  
//
//  Created by Manuel M T Chakravarty on 25/03/2023.
//

import XCTest
@testable import CodeEditorView
@testable import LanguageSupport

final class TokenTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testSimpleTokenise() throws {
    let code =
"""
// 15 "abc"
let str = "xyz"
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift()),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 0

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 0, length: 2))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 3, length: 2))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 6, length: 5))])
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 0, length: 12)])

    // Line 2
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [])
  }

  func testTokeniseAllComment() throws {
    let code =
"""
//
// A Test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift()),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 0, length: 2))])
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 0, length: 3)])

    // Line 2
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.tokens,
                   [ Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 0, length: 2))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 3, length: 1))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 5, length: 4))])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [NSRange(location: 0, length: 9)])
  }

  func testTokeniseWithNewline() throws {
    let code =
"""
// 15 "abc"
let str = "xyz"\n
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift()),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 3)    // code starts at line 1

    // Line 3
    XCTAssertEqual(lineMap.lookup(line: 2)?.info?.tokens, [])
    XCTAssertEqual(lineMap.lookup(line: 2)?.info?.commentRanges, [])
  }

  func testTokeniseCommentAtEnd() throws {
    let code =
"""
let str = "xyz" // 15 "abc"
test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift()),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))
                   , Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 16, length: 2))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 19, length: 2))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 22, length: 5))])
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 16, length: 12)])
  }

  func testTokeniseCommentAtEndMulti() throws {
    let code =
"""
let str = "xyz"
  let x = 15 // 15 "abc"
test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift()),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 3)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))])
    // Line 2
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 2, length: 3))
                     , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 6, length: 1))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 10, length: 2))
                   , Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 13, length: 2))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 16, length: 2))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 19, length: 5))])

    // Comment ranges
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [NSRange(location: 13, length: 12)])
    XCTAssertEqual(lineMap.lookup(line: 2)?.info?.commentRanges, [])
  }

  static var allTests = [
    ("testSimpleTokenise", testSimpleTokenise),
    ("testTokeniseAllComment", testTokeniseAllComment),
    ("testTokeniseWithNewline", testTokeniseWithNewline),
    ("testTokeniseCommentAtEnd", testTokeniseCommentAtEnd),
    ("testTokeniseCommentAtEndMulti", testTokeniseCommentAtEndMulti),
  ]
}
