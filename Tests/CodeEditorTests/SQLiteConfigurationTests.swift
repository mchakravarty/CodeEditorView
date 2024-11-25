//
//  SQLiteConfigurationTests.swift
//  CodeEditorTests
//
//  Created by Ben Barnett on 09/11/2024.
//

import Foundation
import RegexBuilder
import Testing
@testable import CodeEditorView
@testable import LanguageSupport


struct SQLiteNumberTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .sqlite(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid numbers", arguments: validNumbers)
  func tokenisesAsNumber(number: String) throws {
    
    let attributedStringNumber = NSAttributedString(string: number)
    codeStorage.setAttributedString(attributedStringNumber)  // this triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    #expect(lineMap.lines.count == 1)
    
    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "A token should be found")
    #expect(tokens.count == 1, "A single token should be found")
    
    let expectedToken = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>.Token(
      token: .number,
      range: NSRange(location: 0, length: attributedStringNumber.length)
    )
    #expect(tokens.first == expectedToken)
  }
  
  private static var validNumbers: [String] = [
      "1",
      "12.023",
      ".023",
      "1_000",
      "1_000.000_001",
      "1e-1_000",
      "7e+23",
      "0xfaff",
      "0xfa_ff",
    ]
  
}

struct SQLiteIdentifierTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .sqlite(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid identifiers", arguments: validIdentifiers)
  func tokenisesAsIdentifier(text: String) throws {
    let attributedStringValue = NSAttributedString(string: text)
    codeStorage.setAttributedString(attributedStringValue)  // this triggers tokenisation
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
    codeStorage.setAttributedString(attributedStringValue)  // this triggers tokenisation
    let lineMap = codeStorageDelegate.lineMap
    #expect(lineMap.lines.count == 1)
    
    let tokens = try #require(lineMap.lookup(line: 0)?.info?.tokens, "Tokens should be found")
    #expect(tokens.count > 1, "Multiple tokens should be found")
  }
  
  private static var validIdentifiers: [String] = [
      "tbl",
      "_table",
      "a_table",
      "abc123",
      "😀",
      "z̷̡̢͚̺̗͉̖̝͇͈͙̮̻̏̑̆̓͌̒̕̚͝͝ͅͅͅắ̴̡̢͎͇̮̮̠̗̬̰̆͗̃̽̿̔͛̈̿̈̽̇̔̚̕l̸̨͈͔̦̩̠̤͖͚̗̻̥̻͕̭̞̝͆̏̅̕̚g̸͇͎̱̘̘̙̘͕͙͓͈̗̣͍̈́͋̔̓̒͜ͅo̸̝̘͓̾̅͌̂͛̃̈́̊͠͝",
      // Quoted identifiers (not keywords):
      "\"table\"",
      "[table]",
      "`table`",
    ]
  
  private static var invalidIdentifiers: [String] = [
      "1table",
      "table>",
      "tab:le",
    ]
}

struct SQLiteStringTokenisingTests {
  
  let codeStorage: CodeStorage
  let codeStorageDelegate: CodeStorageDelegate
  
  init() {
    codeStorageDelegate = CodeStorageDelegate(with: .sqlite(), setText: { _ in })
    codeStorage = CodeStorage(theme: .defaultLight)
    codeStorage.delegate = codeStorageDelegate
  }
  
  @Test("Recognises valid strings", arguments: validStrings)
  func tokenisesAsString(text: String) throws {
    let attributedStringValue = NSAttributedString(string: text)
    codeStorage.setAttributedString(attributedStringValue)  // this triggers tokenisation
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
  
  private static var validStrings: [String] = [
      "''",
      "'string'",
      "'str''ing'",
      "'str''i''ng'"
    ]
}
