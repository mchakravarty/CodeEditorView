//
//  Tokeniser.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.

import os
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Rearrange


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "Tokeniser")


// MARK: -
// MARK: Regular expression-based tokenisers with explicit state management for context-free constructs

/// Token descriptions
///
public enum TokenPattern: Hashable, Equatable, Comparable {

  /// The token has multiple lexemes, specified in the form of a regular expression string.
  ///
  case pattern(String)  // This case needs to be the first one as we want it to compare as being smaller than the rest;
                        // that ensures that it will appear last in the generated tokeniser regexp and hence match last
                        // in case of overlap.

  /// The token has only one lexeme, given as a simple string. We only match this string if it starts and ends at a
  /// word boundary (as per the "\b" regular expression metacharacter).
  ///
  case word(String)

  /// The token has only one lexeme, given as a simple string.
  ///
  case string(String)
}

public protocol TokeniserState {

  /// Finite projection of tokeniser state to determine sub-tokenisers (and hence, the regular expression to use)
  ///
  associatedtype StateTag: Hashable

  /// Project the tag out of a full state
  ///
  var tag: StateTag { get }
}

/// Type used to attribute characters with their token value.
///
public struct TokenAttribute<TokenType> {

  /// `true` iff this is the first character of a tokens lexeme.
  ///
  public let isHead: Bool

  /// The type of tokens that this character is a part of.
  ///
  public let token: TokenType
}

/// Actions taken in response to matching a token
///
/// The `token` component determines the token type of the matched pattern and `transition` determines the state
/// transition implied by the matched token. If the `transition` component is `nil`, the tokeniser stays in the current
/// state.
///
public typealias TokenAction<TokenType, StateType> = (token: TokenType, transition: ((StateType) -> StateType)?)

/// For each possible state tag of the underlying tokeniser state, a mapping from token patterns to token kinds and
/// maybe a state transition to determine a new tokeniser state
///
public typealias TokenDictionary<TokenType, StateType: TokeniserState>
  = [StateType.StateTag: [TokenPattern: TokenAction<TokenType, StateType>]]

/// Pre-compiled regular expression tokeniser.
///
/// The `TokenType` identifies the various tokens that can be recognised by the tokeniser.
///
public struct Tokeniser<TokenType: Equatable, StateType: TokeniserState> {

  /// The tokens produced by the tokensier.
  ///
  public struct Token: Equatable {

    /// The type of token matched.
    ///
    public let token: TokenType

    /// The range in the tokenised string where the token occurred.
    ///
    public var range: NSRange

    public init(token: TokenType, range: NSRange) {
      self.token = token
      self.range = range
    }

    /// Produce a copy with an adjusted location of the token by shifting it by the given amount.
    ///
    /// - Parameter amount: The amount by which to shift the token. (Positive amounts shift to the right and negative
    ///     ones to the left.)
    ///
    public func shifted(by amount: Int) -> Token {
      return Token(token: token, range: NSRange(location: max(0, range.location + amount), length: range.length))
    }
  }

  /// Tokeniser for one state of the compound tokeniser
  ///
  struct State {

    /// The matching regular expression
    ///
    let regexp: NSRegularExpression

    /// The lookup table for single-lexeme tokens
    ///
    let stringTokenTypes: [String: TokenAction<TokenType, StateType>]

    /// The token types for multi-lexeme tokens
    ///
    /// The order of the token types in the array is the same as that of the matching groups for those tokens in the
    /// regular expression.
    ///
    let patternTokenTypes: [TokenAction<TokenType, StateType>]
  }

  /// Sub-tokeniser for all states of the compound tokeniser
  ///
  let states: [StateType.StateTag: State]

  /// Create a tokeniser from the given token dictionary.
  ///
  /// - Parameters:
  ///   - tokenMap: The token dictionary determining the lexemes to match and their token type.
  /// - Returns: A tokeniser that matches all lexemes contained in the token dictionary.
  ///
  /// The tokeniser is based on an eager regular expression matcher. Hence, it will match the first matching alternative
  /// in a sequence of alternatives. To deal with string patterns, where some patterns may be a prefix of another, the
  /// string patterns are turned into regular expression alternatives longest string first. However, pattern consisting
  /// of regular expressions are tried in an indeterminate order. Hence, no pattern should have as a full match a prefix
  /// of another pattern's full match, to avoid indeterminate results. Moreover, strings match before patterns that
  /// cover the same lexeme.
  ///
  /// For each token that has got a multi-character lexeme, the tokeniser attributes the first character of that lexeme
  /// with a token attribute marked as being the lexeme head character. All other characters of the lexeme —what we call
  /// the token body— are marked with the same token attribute, but without being identified as a lexeme head. This
  /// distinction is crucial to be able to distinguish the boundaries of multiple successive tokens of the same type.
  ///
  public init?(for tokenMap: TokenDictionary<TokenType, StateType>)
  {
    func tokeniser(for stateMap: [TokenPattern: TokenAction<TokenType, StateType>])
    throws -> Tokeniser<TokenType, StateType>.State
    {

      // NB: Be careful with the re-ordering, because the order in `patternTokenTypes` below must match the order of
      //     the patterns in the alternatives of the regular expression. (We must re-order due to eager matching as
      //     explained in the documentation of this function.)
      let orderedMap = stateMap.sorted{ (lhs, rhs) in return lhs.key > rhs.key },
          pattern    = orderedMap.reduce("") { (regexp, mapEntry) in

            let regexpPattern: String
            switch mapEntry.key {
            case .string(let lexeme):   regexpPattern = NSRegularExpression.escapedPattern(for: lexeme)
            case .word(let lexeme):     regexpPattern = "\\b" + NSRegularExpression.escapedPattern(for: lexeme) + "\\b"
            case .pattern(let pattern): regexpPattern = "(" + pattern + ")"     // each pattern gets a capture group
            }
            if regexp.isEmpty { return regexpPattern } else { return regexp + "|" + regexpPattern}
          }
      let stringTokenTypes: [(String, TokenAction<TokenType, StateType>)] = orderedMap.compactMap{ (pattern, type) in
        if case .string(let lexeme) = pattern { return (lexeme, type)  }
        else if case .word(let lexeme) = pattern { return (lexeme, type)  }
        else { return nil }
      }
      let patternTokenTypes: [TokenAction<TokenType, StateType>] = orderedMap.compactMap{ (pattern, type) in
        if case .pattern(_) = pattern { return type } else { return nil }
      }

      let regexp = try NSRegularExpression(pattern: pattern, options: [])
      return Tokeniser.State(regexp: regexp,
                             stringTokenTypes: [String: TokenAction<TokenType, StateType>](stringTokenTypes){
        (left, right) in return left },
                             patternTokenTypes: patternTokenTypes)
    }

    do {

      states = try tokenMap.mapValues{ try tokeniser(for: $0) }

    } catch let err { logger.debug("failed to compile regexp: \(err.localizedDescription)"); return nil }
  }
}

extension NSString {

  /// Parse the given range and set the corresponding token attribute values on all matching lexeme ranges.
  ///
  /// - Parameters:
  ///   - tokeniser: Pre-compiled tokeniser.
  ///   - startState: Starting state of the tokeniser.
  ///   - range: The range in the receiver that is to be parsed and attributed.
  ///
  /// All previously existing occurences of `attribute` in the given range are removed.
  ///
  public func tokenise<TokenType, StateType>(with tokeniser: Tokeniser<TokenType, StateType>,
                                             state startState: StateType,
                                             in range: NSRange?)
  -> [Tokeniser<TokenType, StateType>.Token]
  {
    var state        = startState
    var currentRange = range ?? NSRange(location: 0, length: length)
    var tokens       = [] as [Tokeniser<TokenType, StateType>.Token]

    // Tokenise and set appropriate attributes
    while currentRange.length > 0 {

      guard let stateTokeniser = tokeniser.states[state.tag],
            let result         = stateTokeniser.regexp.firstMatch(in: self as String, options: [], range: currentRange)
      else { break }  // no more match => stop

      // The next lexeme we look for from just after the one we just found
      currentRange = NSRange(location: result.range.max,
                             length: currentRange.length - result.range.max + currentRange.location)

      // If a matching group in the regexp matched, select the action of the correpsonding pattern.
      var tokenAction: TokenAction<TokenType, StateType>?
      for i in stride(from: result.numberOfRanges - 1, through: 1, by: -1) {

        if result.range(at: i).location != NSNotFound { // match by a capture group => complex pattern match

          tokenAction = stateTokeniser.patternTokenTypes[i - 1]
        }
      }

      // If it wasn't a matching group, it must be a simple string match
      if tokenAction == nil {                           // no capture group matched => we matched a simple string lexeme

        tokenAction = stateTokeniser.stringTokenTypes[substring(with: result.range)]
      }

      if let action = tokenAction, result.range.length > 0 {

        tokens.append(.init(token: action.token, range: result.range))

        // If there is an associated state transition function, apply it to the tokeniser state
        if let transition = action.transition { state = transition(state) }

      }
    }
    return tokens
  }
}
