//
//  MutableAttributedString.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//  Extensions to `NSMutableAttributedString`

import os
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


private let logger = Logger(subsystem: "org.justtesting.CodeEditor", category: "MutableAttributedString")


/// Token descriptions
///
enum TokenPattern: Hashable {

  /// The token has only one lexeme, given as a simple string
  ///
  case string(String)

  /// The token has multiple lexemes, specified in the form of a regular expression string
  ///
  case pattern(String)
}

/// Mapping from token patterns to token kinds.
///
typealias TokenDictionary<TokenType> = [TokenPattern: TokenType]

/// Pre-compiled regular expression tokeniser
///
struct Tokeniser<TokenType> {

  /// The matching regular expression
  ///
  let regexp: NSRegularExpression

  /// The lookup table for single-lexeme tokens
  ///
  let stringTokenTypes: [String: TokenType]

  /// The token types for multi-lexeme tokens
  ///
  /// The order of the token types in the array is the same as that of the matching groups for those tokens in the
  /// regular expression.
  ///
  let patternTokenTypes: [TokenType]
}

extension NSMutableAttributedString {

  /// Create a tokeniser from the given token dictionary.
  ///
  /// - Parameter tokenMap: The token dictionary determining the lexemes to match and their token type.
  /// - Returns: A tokeniser that matches all lexemes contained in the token dictionary.
  ///
  static func tokeniser<TokenType>(for tokenMap: TokenDictionary<TokenType>) -> Tokeniser<TokenType>? {

    let pattern = tokenMap.keys.reduce("") { (regexp, pattern) in

      let regexpPattern: String
      switch pattern {
      case .string(let lexeme):   regexpPattern = NSRegularExpression.escapedPattern(for: lexeme)
      case .pattern(let pattern): regexpPattern = "(" + pattern + ")"     // each pattern gets a capture group
      }
      if regexp.isEmpty { return regexpPattern } else { return regexp + "|" + regexpPattern}
    }
    let stringTokenTypes: [(String, TokenType)] = tokenMap.compactMap{ (pattern, type) in
      if case .string(let lexeme) = pattern { return (lexeme, type)  } else { return nil }
    }
    let patternTokenTypes: [TokenType] = tokenMap.compactMap{ (pattern, type) in
      if case .pattern(_) = pattern { return type } else { return nil }
    }

    do {

      let regexp = try NSRegularExpression(pattern: pattern, options: [])
      return Tokeniser(regexp: regexp,
                       stringTokenTypes: Dictionary<String, TokenType>(stringTokenTypes){ (left, right) in return left },
                       patternTokenTypes: patternTokenTypes)

    } catch let err { logger.error("failed to compile regexp: \(err.localizedDescription)"); return nil }
  }

  /// Parse the given range and set the corresponding token attribute value on all matching lexeme ranges.
  ///
  /// - Parameters:
  ///   - attribute: The custom attribute key that identifies token attributes.
  ///   - tokenMap: A dictionary mapping token lexemes to token kinds.
  ///   - regexp: A regular expression that matches all lexemes contained in `tokenMap`.
  ///   - range: The range in the receiver that is to be parsed and attributed.
  ///
  /// All previously existing uses of `attribute` in the given range are removed.
  ///
  func tokeniseAndSetTokenAttribute<TokenType>(attribute: NSAttributedString.Key,
                                               with tokeniser: Tokeniser<TokenType>,
                                               in range: NSRange)
  {
    // Clear existing attributes
    removeAttribute(attribute, range: range)

    // Tokenise and set appropriate attributes
    tokeniser.regexp.enumerateMatches(in: self.string, options: [], range: range) { (result, _, _) in

      guard let result = result else { return }

      var tokenType: TokenType?
      for i in stride(from: result.numberOfRanges - 1, through: 1, by: -1) {

        if result.range(at: i).location != NSNotFound { // match by a capture group => complex pattern match

          tokenType = tokeniser.patternTokenTypes[i - 1]
        }
      }
      if tokenType == nil {                             // no capture group matched => we matched a simple string lexeme

        tokenType = tokeniser.stringTokenTypes[(self.string as NSString).substring(with: result.range)]
      }

      if let value = tokenType { self.addAttribute(attribute, value: value, range: result.range) }
    }
  }
}
