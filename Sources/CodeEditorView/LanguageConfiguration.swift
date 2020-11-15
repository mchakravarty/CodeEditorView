//
//  LanguageConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//
//  Language configurations determine the linguistic characteristics that are important for the editing and display of
//  code in the respective languages, such as comment syntax, bracketing syntax, and syntax highlighting
//  characteristics.

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


/// Specificies the language-dependent aspects of a code editor.
///
public struct LanguageConfiguration {

  /// Supported tokens
  ///
  enum Token {
    case roundBracketOpen
    case roundBracketClose
    case squareBracketOpen
    case squareBracketClose
    case curlyBracketOpen
    case curlyBracketClose
    case string
    case singleLineComment
    case nestedCommentOpen
    case nestedCommentClose
  }

  public typealias BracketPair = (open: String, close: String)

  public let stringRegexp:      String?
  public let singleLineComment: String?
  public let nestedComment:     BracketPair?
}

/// Empty language configuration
///
public let noConfiguration = LanguageConfiguration(stringRegexp: nil,
                                                   singleLineComment: nil,
                                                   nestedComment: nil)

/// Language configuration for Haskell
///
public let haskellConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\"|.)*\"",
                                                        singleLineComment: "--",
                                                        nestedComment: (open: "{-", close: "-}"))

/// Language configuration for Swift
///
public let swiftConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\"|.)*\"",
                                                      singleLineComment: "//",
                                                      nestedComment: (open: "/*", close: "*/"))

extension LanguageConfiguration {

  var tokenDictionary: TokenDictionary<LanguageConfiguration.Token> {

    var tokenDictionary = TokenDictionary<LanguageConfiguration.Token>()

    tokenDictionary.updateValue(Token.roundBracketOpen, forKey: .string("("))
    tokenDictionary.updateValue(Token.roundBracketClose, forKey: .string(")"))
    tokenDictionary.updateValue(Token.squareBracketOpen, forKey: .string("["))
    tokenDictionary.updateValue(Token.squareBracketClose, forKey: .string("]"))
    tokenDictionary.updateValue(Token.curlyBracketOpen, forKey: .string("{"))
    tokenDictionary.updateValue(Token.curlyBracketClose, forKey: .string("}"))
    if let lexeme = stringRegexp { tokenDictionary.updateValue(Token.string, forKey: .pattern(lexeme)) }
    if let lexeme = singleLineComment { tokenDictionary.updateValue(Token.singleLineComment, forKey: .string(lexeme)) }
    if let lexemes = nestedComment {
      tokenDictionary.updateValue(Token.nestedCommentOpen, forKey: .string(lexemes.open))
      tokenDictionary.updateValue(Token.nestedCommentClose, forKey: .string(lexemes.close))
    }

    return tokenDictionary
  }
}
