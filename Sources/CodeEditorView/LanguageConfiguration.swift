//
//  LanguageConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
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

  /// Tokeniser state
  ///
  public enum State: TokeniserState {
    case tokenisingCode
    case tokenisingComment(Int)   // the argument gives the comment nesting depth > 0

    enum Tag: Hashable { case tokenisingCode; case tokenisingComment }

    typealias StateTag = Tag

    var tag: Tag {
      switch self {
      case .tokenisingCode:       return .tokenisingCode
      case .tokenisingComment(_): return .tokenisingComment
      }
    }
  }

  /// Lexeme pair for a bracketing construct
  ///
  public typealias BracketPair = (open: String, close: String)

  /// Regular expression matching strings
  ///
  public let stringRegexp: String?

  /// Lexeme that introduces a single line comment
  public let singleLineComment: String?

  /// A pair of lexemes that encloses a nested comment
  ///
  public let nestedComment: BracketPair?
}

/// Empty language configuration
///
public let noConfiguration = LanguageConfiguration(stringRegexp: nil,
                                                   singleLineComment: nil,
                                                   nestedComment: nil)

/// Language configuration for Haskell
///
public let haskellConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                                        singleLineComment: "--",
                                                        nestedComment: (open: "{-", close: "-}"))

/// Language configuration for Swift
///
public let swiftConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                                      singleLineComment: "//",
                                                      nestedComment: (open: "/*", close: "*/"))

extension LanguageConfiguration {

  func token(_ token: LanguageConfiguration.Token)
    -> (token: LanguageConfiguration.Token, transition: ((LanguageConfiguration.State) -> LanguageConfiguration.State)?)
  {
    return (token: token, transition: nil)
  }

  func incNestedComment(state: LanguageConfiguration.State) -> LanguageConfiguration.State {
    switch state {
    case .tokenisingCode:           return .tokenisingComment(1)
    case .tokenisingComment(let n): return .tokenisingComment(n + 1)
    }
  }

  func decNestedComment(state: LanguageConfiguration.State) -> LanguageConfiguration.State {
    switch state {
    case .tokenisingCode:          return .tokenisingCode
    case .tokenisingComment(let n)
          where n > 1:             return .tokenisingComment(n - 1)
    case .tokenisingComment(_):    return .tokenisingCode
    }
  }

  var tokenDictionary: TokenDictionary<LanguageConfiguration.Token, LanguageConfiguration.State> {

    var tokenDictionary = TokenDictionary<LanguageConfiguration.Token, LanguageConfiguration.State>()

    // Populate the token dictionary for the code state (tokenising plain code)
    //
    var codeTokenDictionary = [TokenPattern: TokenAction<LanguageConfiguration.Token, LanguageConfiguration.State>]()

    codeTokenDictionary.updateValue(token(Token.roundBracketOpen), forKey: .string("("))
    codeTokenDictionary.updateValue(token(Token.roundBracketClose), forKey: .string(")"))
    codeTokenDictionary.updateValue(token(Token.squareBracketOpen), forKey: .string("["))
    codeTokenDictionary.updateValue(token(Token.squareBracketClose), forKey: .string("]"))
    codeTokenDictionary.updateValue(token(Token.curlyBracketOpen), forKey: .string("{"))
    codeTokenDictionary.updateValue(token(Token.curlyBracketClose), forKey: .string("}"))
    if let lexeme = stringRegexp { codeTokenDictionary.updateValue(token(Token.string), forKey: .pattern(lexeme)) }
    if let lexeme = singleLineComment {
      codeTokenDictionary.updateValue(token(Token.singleLineComment), forKey: .string(lexeme))
    }
    if let lexemes = nestedComment {
      codeTokenDictionary.updateValue((token: Token.nestedCommentOpen, transition: incNestedComment),
                                      forKey: .string(lexemes.open))
      codeTokenDictionary.updateValue((token: Token.nestedCommentClose, transition: decNestedComment),
                                      forKey: .string(lexemes.close))
    }

    tokenDictionary.updateValue(codeTokenDictionary, forKey: .tokenisingCode)

    // Populate the token dictionary for the comment state (tokenising within a nested comment)
    //
    var commentTokenDictionary = [TokenPattern: TokenAction<LanguageConfiguration.Token, LanguageConfiguration.State>]()

    if let lexemes = nestedComment {
      commentTokenDictionary.updateValue((token: Token.nestedCommentOpen, transition: incNestedComment),
                                         forKey: .string(lexemes.open))
      commentTokenDictionary.updateValue((token: Token.nestedCommentClose, transition: decNestedComment),
                                         forKey: .string(lexemes.close))
    }

    tokenDictionary.updateValue(commentTokenDictionary, forKey: .tokenisingComment)

    return tokenDictionary
  }
}
