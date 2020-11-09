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
    case singleLineComment
    case nestedCommentOpen
    case nestedCommentClose
  }

  public typealias BracketPair = (open: String, close: String)

  public let singleLineComment: String?
  public let nestedComment: BracketPair?
}

/// Empty language configuration
///
public let noConfiguration = LanguageConfiguration(singleLineComment: nil,
                                                   nestedComment: nil)

/// Language configuration for Haskell
///
public let haskellConfiguration = LanguageConfiguration(singleLineComment: "--",
                                                        nestedComment: (open: "{-", close: "-}"))

/// Language configuration for Swift
///
public let swiftConfiguration = LanguageConfiguration(singleLineComment: "//",
                                                      nestedComment: (open: "/*", close: "*/"))

extension LanguageConfiguration {

  var tokenDictionary: TokenDictionary<LanguageConfiguration.Token> {

    var tokenDictionary = TokenDictionary<LanguageConfiguration.Token>()

    if let lexeme = singleLineComment { tokenDictionary.updateValue(Token.singleLineComment, forKey: lexeme) }
    if let lexeme = nestedComment?.open { tokenDictionary.updateValue(Token.nestedCommentOpen, forKey: lexeme) }
    if let lexeme = nestedComment?.close { tokenDictionary.updateValue(Token.nestedCommentClose, forKey: lexeme) }

    return tokenDictionary
  }
}
