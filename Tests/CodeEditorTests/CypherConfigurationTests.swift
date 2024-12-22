//
//  CypherConfigurationTests.swift
//
//
//  Created by Carlo Rapisarda on 2024-12-22.
//

import Foundation
import RegexBuilder
import Testing
@testable import CodeEditorView
@testable import LanguageSupport

struct CypherNumberTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .cypher(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid numbers", arguments: validNumbers)
  func tokenisesAsNumber(number: String) throws {
    let attributedString = NSAttributedString(string: number)
    codeStorage.setAttributedString(attributedString)  // triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    
    #expect(lineMap.lines.count == 1)

    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "A token should be found")
    #expect(tokens.count == 1, "A single token should be found")
    
    let expectedToken = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>.Token(
      token: .number,
      range: NSRange(location: 0, length: attributedString.length)
    )
    #expect(tokens.first == expectedToken)
  }
  
  /// A few examples of numeric literals that should be valid in Cypher:
  private static var validNumbers: [String] = [
    "42",
    "-42",
    "3.14159",
    "0.5",
    "-0.5",
    "123.456e2",
    "-2.5E-3",
    "1E+6"
  ]
}

struct CypherIdentifierTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .cypher(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid identifiers", arguments: validIdentifiers)
  func tokenisesAsIdentifier(text: String) throws {
    let attributedStringValue = NSAttributedString(string: text)
    codeStorage.setAttributedString(attributedStringValue)  // triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    
    #expect(lineMap.lines.count == 1)
    
    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "A token should be found")
    #expect(tokens.count == 1, "A single token should be found")
    
    let expectedToken = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>.Token(
      token: .identifier(nil),
      range: NSRange(location: 0, length: attributedStringValue.length)
    )
    #expect(tokens.first == expectedToken)
  }
  
  @Test("Recognises invalid identifiers", arguments: invalidIdentifiers)
  func tokenisesAsNonIdentifier(text: String) throws {
    let attributedStringValue = NSAttributedString(string: text)
    codeStorage.setAttributedString(attributedStringValue)  // triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    
    #expect(lineMap.lines.count == 1)
    
    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "Tokens should be found")
    #expect(tokens.count > 1, "Multiple tokens should be found if it's not a single valid identifier.")
  }
  
  /// Valid Cypher identifiers:
  ///  - Unquoted: start with letter or underscore, followed by letters, digits, underscores
  ///  - Backtick-quoted: can contain more varied characters
  private static var validIdentifiers: [String] = [
    "n",
    "_node",
    "abc123",
    "my_label",
    "`some weird stuff`",
    "`Person:Label`",
    "`some backtick: literal with !@#$%^&*()`",
  ]
  
  /// Some invalid identifier examples (leading digit, invalid symbol, etc.)
  private static var invalidIdentifiers: [String] = [
    "1abc",        // leading digit
    "node!",       // exclamation mark outside backticks
    "my-node"      // hyphen not allowed in unquoted
  ]
}

struct CypherStringTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .cypher(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid strings", arguments: validStrings)
  func tokenisesAsString(text: String) throws {
    let attributedStringValue = NSAttributedString(string: text)
    codeStorage.setAttributedString(attributedStringValue)  // triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    
    #expect(lineMap.lines.count == 1)
    
    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "A token should be found")
    #expect(tokens.count == 1, "A single token should be found")
    
    let expectedToken = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>.Token(
      token: .string,
      range: NSRange(location: 0, length: attributedStringValue.length)
    )
    #expect(tokens.first == expectedToken)
  }
  
  /// Cypher strings can be single-quoted or double-quoted, with doubling of quotes to escape:
  private static var validStrings: [String] = [
    "''",                // empty string in single quotes
    "'Hello World'",
    "'It''s a string'",  // embedded single quote
    "\"\"",
    "\"Hello World\"",
    "\"Double \"\"quote\"\" example\"",
    "'A \"nested\" example with single quotes'",
    "\"A 'nested' example with double quotes\"",
  ]
}
