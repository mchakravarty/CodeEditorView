//
//  TokenTests.swift
//  
//
//  Created by Manuel M T Chakravarty on 25/03/2023.
//

import RegexBuilder
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
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
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
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [])
  }

  func testTokeniseAllComment() throws {
    let code =
"""
//
// A Test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
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
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
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
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))
                   , Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 16, length: 2))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 19, length: 2))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 22, length: 5))])

    // Comment ranges
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 16, length: 12)])
  }

  func testTokeniseCommentAtEndMulti() throws {
    let code =
"""
let str = "xyz"
  let x = 15 // 15 "abc"
test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 3)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))])
    // Line 2
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 2, length: 3))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 6, length: 1))
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 10, length: 2))
                   , Tokeniser.Token(token: .singleLineComment, range: NSRange(location: 13, length: 2))
                   , Tokeniser.Token(token: .number, range: NSRange(location: 16, length: 2))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 19, length: 5))])

    // Comment ranges
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [NSRange(location: 13, length: 12)])
    XCTAssertEqual(lineMap.lookup(line: 2)?.info?.commentRanges, [])
  }

  func testTokeniseNestedComment() throws {
    let code =
"""
let str = "xyz" /* 15 "abc"*/
test
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))
                   , Tokeniser.Token(token: .nestedCommentOpen, range: NSRange(location: 16, length: 2))
                   , Tokeniser.Token(token: .nestedCommentClose, range: NSRange(location: 27, length: 2))])

    // Comment ranges
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 16, length: 13)])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [])
  }

  func testTokeniseMultiLineNestedComment() throws {
    let code =
"""
let str = "xyz" /* 15 "abc"
test */
"""
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation

    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 2)    // code starts at line 1

    // Line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 3))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 4, length: 3))
                   , Tokeniser.Token(token: .symbol, range: NSRange(location: 8, length: 1))
                   , Tokeniser.Token(token: .string, range: NSRange(location: 10, length: 5))
                   , Tokeniser.Token(token: .nestedCommentOpen, range: NSRange(location: 16, length: 2))])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.tokens,
                   [ Tokeniser.Token(token: .nestedCommentClose, range: NSRange(location: 5, length: 2))])

    // Comment ranges
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.commentRanges, [NSRange(location: 16, length: 12)])
    XCTAssertEqual(lineMap.lookup(line: 1)?.info?.commentRanges, [NSRange(location: 0, length: 7)])
  }
  
  func testCaseInsensitiveReservedIdentifiersUnspecified() throws {
    let lowerCaseCode = "struct SomeType {}"
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
    
    codeStorage.setAttributedString(NSAttributedString(string: lowerCaseCode))  // this triggers tokenisation
    
    let lowerCaseLineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lowerCaseLineMap.lines.count, 1)    // code starts at line 1
    XCTAssertEqual(lowerCaseLineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 6))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 7, length: 8))
                   , Tokeniser.Token(token: .curlyBracketOpen, range: NSRange(location: 16, length: 1))
                   , Tokeniser.Token(token: .curlyBracketClose, range: NSRange(location: 17, length: 1))])
    
    let upperCaseCode = "STRUCT SomeType {}"
    codeStorage.setAttributedString(NSAttributedString(string: upperCaseCode))  // this triggers tokenisation
    
    let upperCaseLineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(upperCaseLineMap.lines.count, 1)    // code starts at line 1
    XCTAssertEqual(upperCaseLineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 0, length: 6))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 7, length: 8))
                   , Tokeniser.Token(token: .curlyBracketOpen, range: NSRange(location: 16, length: 1))
                   , Tokeniser.Token(token: .curlyBracketClose, range: NSRange(location: 17, length: 1))])
  }
  
  func testCaseInsensitiveReservedIdentifiersFalse() throws {
    let lowerCaseCode = "struct SomeType {}"
    let codeStorageDelegate = CodeStorageDelegate(with: .structCaseSensitive, setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
    
    codeStorage.setAttributedString(NSAttributedString(string: lowerCaseCode))  // this triggers tokenisation
    
    let lowerCaseLineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lowerCaseLineMap.lines.count, 1)    // code starts at line 1
    XCTAssertEqual(lowerCaseLineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 6))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 7, length: 8))
                   , Tokeniser.Token(token: .curlyBracketOpen, range: NSRange(location: 16, length: 1))
                   , Tokeniser.Token(token: .curlyBracketClose, range: NSRange(location: 17, length: 1))])
    
    let upperCaseCode = "STRUCT SomeType {}"
    codeStorage.setAttributedString(NSAttributedString(string: upperCaseCode))  // this triggers tokenisation
    
    let upperCaseLineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(upperCaseLineMap.lines.count, 1)    // code starts at line 1
    XCTAssertEqual(upperCaseLineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 0, length: 6))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 7, length: 8))
                   , Tokeniser.Token(token: .curlyBracketOpen, range: NSRange(location: 16, length: 1))
                   , Tokeniser.Token(token: .curlyBracketClose, range: NSRange(location: 17, length: 1))])
  }
  
  func testCaseInsensitiveReservedIdentifiersTrue() throws {
    let code = "STRUCT SomeType {}"
    let codeStorageDelegate = CodeStorageDelegate(with: .structCaseInsensitive, setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
    
    codeStorage.setAttributedString(NSAttributedString(string: code))  // this triggers tokenisation
    
    let lineMap = codeStorageDelegate.lineMap
    XCTAssertEqual(lineMap.lines.count, 1)    // code starts at line 1
    XCTAssertEqual(lineMap.lookup(line: 0)?.info?.tokens,
                   [ Tokeniser.Token(token: .keyword, range: NSRange(location: 0, length: 6))
                   , Tokeniser.Token(token: .identifier(.none), range: NSRange(location: 7, length: 8))
                   , Tokeniser.Token(token: .curlyBracketOpen, range: NSRange(location: 16, length: 1))
                   , Tokeniser.Token(token: .curlyBracketClose, range: NSRange(location: 17, length: 1))])
  }

  func testInsertNewlineAfterEmoji() throws {
    // Test case for UTF-16 indexing issue with emojis
    // The emoji 🏁 is 1 Character but 2 UTF-16 code units
    // When inserting at the end, the UTF-16 offset differs from the Character offset
    let code = "flag: 🏁 fumble"
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))

    // Verify initial state
    XCTAssertEqual(code.count, 14)  // 14 Characters
    XCTAssertEqual((code as NSString).length, 15)  // 15 UTF-16 code units

    // Simulate inserting a newline at the very end (UTF-16 position 15)
    // This should not crash
    codeStorage.replaceCharacters(in: NSRange(location: 15, length: 0), with: "\n")

    // Verify the insertion succeeded
    XCTAssertEqual(codeStorage.string, "flag: 🏁 fumble\n")
  }

  func testInsertCharacterAfterMultipleEmojis() throws {
    // Test with multiple emojis to stress test UTF-16 handling
    let code = "🏁🎉🚀"
    let codeStorageDelegate = CodeStorageDelegate(with: .swift(), setText: { _ in }),
        codeStorage         = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate

    codeStorage.setAttributedString(NSAttributedString(string: code))

    // 3 Characters, 6 UTF-16 code units
    XCTAssertEqual(code.count, 3)
    XCTAssertEqual((code as NSString).length, 6)

    // Insert at the end - should not crash
    codeStorage.replaceCharacters(in: NSRange(location: 6, length: 0), with: "x")
    XCTAssertEqual(codeStorage.string, "🏁🎉🚀x")

    // Insert in the middle after 🏁 (UTF-16 position 2)
    codeStorage.replaceCharacters(in: NSRange(location: 2, length: 0), with: "y")
    XCTAssertEqual(codeStorage.string, "🏁y🎉🚀x")
  }

  static var allTests = [
    ("testSimpleTokenise", testSimpleTokenise),
    ("testTokeniseAllComment", testTokeniseAllComment),
    ("testTokeniseWithNewline", testTokeniseWithNewline),
    ("testTokeniseCommentAtEnd", testTokeniseCommentAtEnd),
    ("testTokeniseCommentAtEndMulti", testTokeniseCommentAtEndMulti),
    ("testTokeniseNestedComment", testTokeniseNestedComment),
    ("testTokeniseMultiLineNestedComment", testTokeniseMultiLineNestedComment),
    ("testCaseInsensitiveReservedIdentifiersUnspecified", testCaseInsensitiveReservedIdentifiersUnspecified),
    ("testCaseInsensitiveReservedIdentifiersFalse", testCaseInsensitiveReservedIdentifiersFalse),
    ("testCaseInsensitiveReservedIdentifiersTrue", testCaseInsensitiveReservedIdentifiersTrue),
    ("testInsertNewlineAfterEmoji", testInsertNewlineAfterEmoji),
    ("testInsertCharacterAfterMultipleEmojis", testInsertCharacterAfterMultipleEmojis),
  ]
}

extension LanguageConfiguration {
  private static let plainIdentifierRegex: Regex<Substring> = Regex {
    identifierHeadCharacters
    ZeroOrMore {
      identifierCharacters
    }
  }
  
  fileprivate static var structCaseSensitive: LanguageConfiguration {
    LanguageConfiguration(
      name: "StructCaseUnspecified",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      caseInsensitiveReservedIdentifiers: false,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: plainIdentifierRegex,
      operatorRegex: nil,
      reservedIdentifiers: ["struct"],
      reservedOperators: [],
      languageService: nil
    )
  }
  
  fileprivate static var structCaseInsensitive: LanguageConfiguration {
    LanguageConfiguration(
      name: "StructCaseInsensitive",
      supportsSquareBrackets: true,
      supportsCurlyBrackets: true,
      caseInsensitiveReservedIdentifiers: true,
      stringRegex: nil,
      characterRegex: nil,
      numberRegex: nil,
      singleLineComment: nil,
      nestedComment: nil,
      identifierRegex: plainIdentifierRegex,
      operatorRegex: nil,
      reservedIdentifiers: ["struct"],
      reservedOperators: [],
      languageService: nil
    )
  }
}
