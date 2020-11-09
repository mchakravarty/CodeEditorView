//
//  MutableAttributedString.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//  Extensions to `NSMutableAttributedString`

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


/// Mapping from token lexemes to token kinds.
///
typealias TokenDictionary<TokenType> = [String: TokenType]

extension NSMutableAttributedString {

  /// Determine a regular expression matching all lexemes in the given token dictionary.
  ///
  /// - Parameter tokenMap: The token dictionary determining the lexemes to match.
  /// - Returns: A regular expression that is able to match all lexemes contained in the token dictionary.
  ///
  static func regularExpression<TokenType>(for tokenMap: TokenDictionary<TokenType>) -> NSRegularExpression? {
    let pattern = tokenMap.keys.reduce("") { (regexp, lexeme) in
      if regexp.isEmpty { return NSRegularExpression.escapedPattern(for: lexeme) }
      else { return regexp + "|" + NSRegularExpression.escapedPattern(for: lexeme) }
    }
    return try? NSRegularExpression(pattern: pattern, options: [])
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
  func determineAndSetTokenAttribute<TokenType>(attribute: NSAttributedString.Key,
                                                tokenMap: TokenDictionary<TokenType>,
                                                with regexp: NSRegularExpression,
                                                in range: NSRange)
  {
    // Clear existing attributes
    removeAttribute(attribute, range: range)

    // Tokenise and set appropriate attributes
    regexp.enumerateMatches(in: self.string, options: [], range: range) { (result, _, _) in

      guard
        let result = result,
        let value  = tokenMap[(self.string as NSString).substring(with: result.range)]
      else { return }

      self.addAttribute(attribute, value: value, range: result.range)
    }
  }
}
