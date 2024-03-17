//
//  Tokeniser.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.

import os
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import RegexBuilder

import Rearrange


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "Tokeniser")


// MARK: -
// MARK: Regular expression-based tokenisers with explicit state management for context-free constructs

/// Actions taken in response to matching a token
///
/// The `token` component determines the token type of the matched pattern and `transition` determines the state
/// transition implied by the matched token. If the `transition` component is `nil`, the tokeniser stays in the current
/// state.
///
public typealias TokenAction<TokenType, StateType> = (token: TokenType, transition: ((StateType) -> StateType)?)

/// Token descriptions
///
public struct TokenDescription<TokenType, StateType> {

  /// The regex to match the token.
  ///
  public let regex: Regex<Substring>

  /// If the token has only got a single lexeme, it is specified here.
  ///
  public let singleLexeme: String?

  /// The action to take when the token gets matched.
  ///
  public let action: TokenAction<TokenType, StateType>

  public init(regex: Regex<Substring>, singleLexeme: String? = nil, action: TokenAction<TokenType, StateType>) {
    self.regex        = regex
    self.singleLexeme = singleLexeme
    self.action       = action
  }
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

/// For each possible state tag of the underlying tokeniser state, a mapping from token patterns to token kinds and
/// maybe a state transition to determine a new tokeniser state.
///
/// The matching of single lexeme tokens takes precedence over tokens with multiple lexemes. Within each category
/// (single or multiple lexeme tokens), the order of the token description in the array indicates the order of matching
/// preference; i.e., earlier elements take precedence.
///
public typealias TokenDictionary<TokenType, StateType: TokeniserState>
  = [StateType.StateTag: [TokenDescription<TokenType, StateType>]]

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

    /// The regular expression used for matching in this state.
    ///
    /// The first capture in this regex is for the whole lot of single-lexeme tokens. The rest is for the multi-lexeme
    /// tokens, one each.
    ///
    let regex: Regex<AnyRegexOutput>

    /// The lookup table for single-lexeme tokens.
    ///
    let stringTokenTypes: [String: TokenAction<TokenType, StateType>]

    /// The token types for multi-lexeme tokens.
    ///
    /// The order of the token types in the array is the same as that of the matching groups for those tokens in the
    /// regular expression.
    ///
    let patternTokenTypes: [TokenAction<TokenType, StateType>]
  }

  /// Sub-tokeniser for all states of the compound tokeniser.
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
    func combine(alternatives: [TokenDescription<TokenType, StateType>]) -> Regex<Substring>? {
      switch alternatives.count {
      case 0:  return nil
      case 1:  return alternatives[0].regex
      default: return alternatives[1...].reduce(alternatives[0].regex) { (regex, alternative) in
        Regex { ChoiceOf { regex; alternative.regex } }
      }
      }
    }

    func combineWithCapture(alternatives: [TokenDescription<TokenType, StateType>]) -> Regex<AnyRegexOutput>? {
      switch alternatives.count {
      case 0:  return nil
      case 1:  return Regex(Regex { Capture { alternatives[0].regex } })
      default: return alternatives[1...].reduce(Regex(Regex { Capture { alternatives[0].regex } })) { (regex, alternative) in
        Regex(Regex { ChoiceOf { regex; Capture { alternative.regex } } })
      }
      }
    }

    func tokeniser(for stateMap: [TokenDescription<TokenType, StateType>]) -> Tokeniser<TokenType, StateType>.State?
    {

      let singleLexemeTokens      = stateMap.filter{ $0.singleLexeme != nil },
          multiLexemeTokens       = stateMap.filter{ $0.singleLexeme == nil },
          singleLexemeTokensRegex = combine(alternatives: singleLexemeTokens),
          multiLexemeTokensRegex  = combineWithCapture(alternatives: multiLexemeTokens)

      let stringTokenTypes: [(String, TokenAction<TokenType, StateType>)] = singleLexemeTokens.compactMap {
        if let lexeme = $0.singleLexeme { (lexeme, $0.action) } else { nil }
      }
      let patternTokenTypes = multiLexemeTokens.map{ $0.action }

      let regex: Regex<AnyRegexOutput>?  = switch (singleLexemeTokensRegex, multiLexemeTokensRegex) {
                                           case (nil, nil):
                                             nil
                                           case (.some(let single), nil):
                                             Regex(Regex { Capture { single } })
                                           case (nil, .some(let multi)):
                                             multi
                                           case (.some(let single), .some(let multi)):
                                             Regex(Regex { ChoiceOf {
                                               Capture { single }
                                               multi
                                             }})
                                           }
      return if let regex {

        Tokeniser.State(regex: regex,
                        stringTokenTypes: [String: TokenAction<TokenType, StateType>](stringTokenTypes){
                                            (left, right) in return left },
                        patternTokenTypes: patternTokenTypes)

      } else { nil }
    }

    states = tokenMap.compactMapValues{ tokeniser(for: $0) }
    if states.isEmpty { logger.debug("failed to compile regexp"); return nil }
  }
}

extension StringProtocol {

  /// Tokenise the given range and return the encountered tokens.
  ///
  /// - Parameters:
  ///   - tokeniser: Pre-compiled tokeniser.
  ///   - startState: Starting state of the tokeniser.
  /// - Returns: The sequence of the encountered tokens.
  ///
  public func tokenise<TokenType, StateType>(with tokeniser: Tokeniser<TokenType, StateType>,
                                             state startState: StateType)
  -> [Tokeniser<TokenType, StateType>.Token]
  {
    var state        = startState
    var currentStart = startIndex
    var tokens       = [] as [Tokeniser<TokenType, StateType>.Token]

    // Tokenise and set appropriate attributes
    while currentStart < endIndex {

      guard let stateTokeniser   = tokeniser.states[state.tag],
            let currentSubstring = self[currentStart...] as? Substring,
            let result           = try? stateTokeniser.regex.firstMatch(in: currentSubstring)
      else { break }  // no more match => stop

      // We are going to look for the next lexeme from just after the one we just found
      currentStart = result.range.upperBound

      var tokenAction: TokenAction<TokenType, StateType>?
      if result[1].range != nil {     // that is the capture for the whole lot of single lexeme tokens

        tokenAction = stateTokeniser.stringTokenTypes[String(self[result.range])]

      } else {

        // If a matching group in the regexp matched, select the action of the corresponding pattern.
        for i in 2..<result.count {

          if result[i].range != nil { // match by a capture group => complex pattern match

            tokenAction = stateTokeniser.patternTokenTypes[i - 2]
            break
          }
        }
      }

      if let action = tokenAction, !result.range.isEmpty {

        tokens.append(.init(token: action.token, range: NSRange(result.range, in: self)))

        // If there is an associated state transition function, apply it to the tokeniser state
        if let transition = action.transition { state = transition(state) }

      }
    }
    return tokens
  }
}

