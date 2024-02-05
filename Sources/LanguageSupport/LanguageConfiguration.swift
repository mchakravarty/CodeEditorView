//
//  LanguageConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//  Language configurations determine the linguistic characteristics that are important for the editing and display of
//  code in the respective languages, such as comment syntax, bracketing syntax, and syntax highlighting
//  characteristics.
//
//  We adopt a two-stage approach to syntax highlighting. In the first stage, basic context-free syntactic constructs
//  are being highlighted. In the second stage, contextual highlighting is performed on top of the highlighting from
//  stage one. The second stage relies on information from a code analysis subsystem, such as SourceKit.
//
//  Curent support here is only for the first stage.

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


/// Specifies the language-dependent aspects of a code editor.
///
public struct LanguageConfiguration {

  /// The various categories of types.
  ///
  public enum TypeFlavour: Equatable {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case other
  }

  /// Flavours of identifiers and operators.
  ///
  public enum Flavour: Equatable {
    case module
    case `type`(TypeFlavour)
    case parameter
    case typeParameter
    case variable
    case property
    case enumCase
    case function
    case method
    case macro
    case modifier

    public var isType: Bool {
      switch self {
      case .type: return true
      default: return false
      }
    }
  }

  /// Supported kinds of tokens.
  ///
  public enum Token: Equatable {
    case roundBracketOpen
    case roundBracketClose
    case squareBracketOpen
    case squareBracketClose
    case curlyBracketOpen
    case curlyBracketClose
    case string
    case character
    case number
    case singleLineComment
    case nestedCommentOpen
    case nestedCommentClose
    case identifier(Flavour?)
    case `operator`(Flavour?)
    case keyword
    case regexp

    public var isOpenBracket: Bool {
      switch self {
      case .roundBracketOpen, .squareBracketOpen, .curlyBracketOpen, .nestedCommentOpen: return true
      default:                                                                           return false
      }
    }

    public var isCloseBracket: Bool {
      switch self {
      case .roundBracketClose, .squareBracketClose, .curlyBracketClose, .nestedCommentClose: return true
      default:                                                                               return false
      }
    }

    public var matchingBracket: Token? {
      switch self {
      case .roundBracketOpen:   return .roundBracketClose
      case .squareBracketOpen:  return .squareBracketClose
      case .curlyBracketOpen:   return .curlyBracketClose
      case .nestedCommentOpen:  return .nestedCommentClose
      case .roundBracketClose:  return .roundBracketOpen
      case .squareBracketClose: return .squareBracketOpen
      case .curlyBracketClose:  return .curlyBracketOpen
      case .nestedCommentClose: return .nestedCommentOpen
      default:                  return nil
      }
    }

    public var isComment: Bool {
      switch self {
      case .singleLineComment:  return true
      case .nestedCommentOpen:  return true
      case .nestedCommentClose: return true
      default:                  return false
      }
    }

    public var isIdentifier: Bool {
      switch self {
      case .identifier: return true
      default: return false
      }
    }

    public var isOperator: Bool {
      switch self {
      case .operator: return true
      default: return false
      }
    }
  }

  /// Tokeniser state
  ///
  public enum State: TokeniserState {
    case tokenisingCode
    case tokenisingComment(Int)   // the argument gives the comment nesting depth > 0

    public enum Tag: Hashable { case tokenisingCode; case tokenisingComment }

    public typealias StateTag = Tag

    public var tag: Tag {
      switch self {
      case .tokenisingCode:       return .tokenisingCode
      case .tokenisingComment(_): return .tokenisingComment
      }
    }
  }

  /// Lexeme pair for a bracketing construct
  ///
  public typealias BracketPair = (open: String, close: String)

  /// The name of the language.
  ///
  public let name: String

  /// Regular expression matching strings
  ///
  public let stringRegexp: String?

  /// Regular expression matching character literals
  ///
  public let characterRegexp: String?

  /// Regular expression matching numbers
  ///
  public let numberRegexp: String?

  /// Lexeme that introduces a single line comment
  ///
  public let singleLineComment: String?

  /// A pair of lexemes that encloses a nested comment
  ///
  public let nestedComment: BracketPair?

  /// Regular expression matching all identifiers (even if they are subgroupings)
  ///
  public let identifierRegexp: String?

  /// Reserved identifiers (this does not include contextual keywords)
  ///
  public let reservedIdentifiers: [String]

  /// Dynamic language service that provides advanced syntactic as well as semantic information.
  ///
  public let languageService: LanguageServiceBuilder?

  public init(name: String,
              stringRegexp: String?,
              characterRegexp: String?,
              numberRegexp: String?,
              singleLineComment: String?,
              nestedComment: LanguageConfiguration.BracketPair?,
              identifierRegexp: String?,
              reservedIdentifiers: [String],
              languageService: LanguageServiceBuilder? = nil)
  {
    self.name                 = name
    self.stringRegexp         = stringRegexp
    self.characterRegexp      = characterRegexp
    self.numberRegexp         = numberRegexp
    self.singleLineComment    = singleLineComment
    self.nestedComment        = nestedComment
    self.identifierRegexp     = identifierRegexp
    self.reservedIdentifiers  = reservedIdentifiers
    self.languageService      = languageService
  }

  /// Yields the lexeme of the given token under this language configuration if the token has got a unique lexeme.
  ///
  public func lexeme(of token: Token) -> String? {
    switch token {
    case .roundBracketOpen:   return "("
    case .roundBracketClose:  return ")"
    case .squareBracketOpen:  return "["
    case .squareBracketClose: return "]"
    case .curlyBracketOpen:   return "{"
    case .curlyBracketClose:  return "}"
    case .string:             return nil
    case .character:          return nil
    case .number:             return nil
    case .singleLineComment:  return singleLineComment
    case .nestedCommentOpen:  return nestedComment?.open
    case .nestedCommentClose: return nestedComment?.close
    case .identifier:         return nil
    case .operator:           return nil
    case .keyword:            return nil
    case .regexp:             return nil
    }
  }
}

extension LanguageConfiguration {

  /// Empty language configuration
  ///
  public static let none = LanguageConfiguration(name: "Text",
                                                 stringRegexp: nil,
                                                 characterRegexp: nil,
                                                 numberRegexp: nil,
                                                 singleLineComment: nil,
                                                 nestedComment: nil,
                                                 identifierRegexp: nil,
                                                 reservedIdentifiers: [])

}

extension LanguageConfiguration {

  // General purpose numeric literals
  public static let binaryLit    = "(?:[01]_*)+"
  public static let octalLit     = "(?:[0-7]_*)+"
  public static let decimalLit   = "(?:[0-9]_*)+"
  public static let hexalLit     = "(?:[0-9A-Fa-f]_*)+"
  public static let optNegation  = "(?:\\B-|\\b)"
  public static let exponentLit  = "[eE](?:[+-])?" + decimalLit
  public static let hexponentLit = "[pP](?:[+-])?" + decimalLit

  // Identifier components following the Swift 5.4 reference
  public static let identifierHeadChar
    = "["
    + "[a-zA-Z_]"
    + "[\u{00A8}\u{00AA}\u{00AD}\u{00AF}\u{00B2}–\u{00B5}\u{00B7}–\u{00BA}]"
    + "[\u{00BC}–\u{00BE}\u{00C0}–\u{00D6}\u{00D8}–\u{00F6}\u{00F8}–\u{00FF}]"
    + "[\u{0100}–\u{02FF}\u{0370}–\u{167F}\u{1681}–\u{180D}\u{180F}–\u{1DBF}]"
    + "[\u{1E00}–\u{1FFF}]"
    + "[\u{200B}–\u{200D}\u{202A}–\u{202E}\u{203F}–\u{2040}\u{2054}\u{2060}–\u{206F}]"
    + "[\u{2070}–\u{20CF}\u{2100}–\u{218F}\u{2460}–\u{24FF}\u{2776}–\u{2793}]"
    + "[\u{2C00}–\u{2DFF}\u{2E80}–\u{2FFF}]"
    + "[\u{3004}–\u{3007}\u{3021}–\u{302F}\u{3031}–\u{303F}\u{3040}–\u{D7FF}]"
    + "[\u{F900}–\u{FD3D}\u{FD40}–\u{FDCF}\u{FDF0}–\u{FE1F}\u{FE30}–\u{FE44}]"
    + "[\u{FE47}–\u{FFFD}]"
    + "[\u{10000}–\u{1FFFD}\u{20000}–\u{2FFFD}\u{30000}–\u{3FFFD}\u{40000}–\u{4FFFD}]"
    + "[\u{50000}–\u{5FFFD}\u{60000}–\u{6FFFD}\u{70000}–\u{7FFFD}\u{80000}–\u{8FFFD}]"
    + "[\u{90000}–\u{9FFFD}\u{A0000}–\u{AFFFD}\u{B0000}–\u{BFFFD}\u{C0000}–\u{CFFFD}]"
    + "[\u{D0000}–\u{DFFFD}\u{E0000}–\u{EFFFD}]"
    + "]"
  public static let identifierBodyChar
    = "["
    + "[0-9]"
    + "[\u{0300}–\u{036F}\u{1DC0}–\u{1DFF}\u{20D0}–\u{20FF}\u{FE20}–\u{FE2F}]"
    + "]"

  /// Wrap a regular expression into grouping brackets.
  ///
  public static func group(_ regexp: String) -> String { "(?:" + regexp + ")" }

  /// Compose an array of regular expressions as alternatives.
  ///
  public static func alternatives(_ alts: [String]) -> String { alts.map{ group($0) }.joined(separator: "|") }
}

/// Tokeniser generated on the basis of a language configuration.
///
typealias LanguageConfigurationTokenDictionary = TokenDictionary<LanguageConfiguration.Token,
                                                                  LanguageConfiguration.State>

/// Tokeniser generated on the basis of a language configuration.
///
public typealias LanguageConfigurationTokeniser = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>

extension LanguageConfiguration {

  /// Tokeniser generated on the basis of a language configuration.
  ///
  public typealias Tokeniser = LanguageSupport.Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>

  /// Token dictionary generated on the basis of a language configuration.
  ///
  public typealias TokenDictionary = LanguageSupport.TokenDictionary<LanguageConfiguration.Token,
                                                                      LanguageConfiguration.State>

  /// Token action generated on the basis of a language configuration.
  ///
  public typealias TokenAction = LanguageSupport.TokenAction <LanguageConfiguration.Token, LanguageConfiguration.State>

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

  public var tokenDictionary: TokenDictionary {

    var tokenDictionary = TokenDictionary()

    // Populate the token dictionary for the code state (tokenising plain code)
    //
    var codeTokenDictionary = [TokenPattern: TokenAction]()

    codeTokenDictionary.updateValue(token(.roundBracketOpen), forKey: .string("("))
    codeTokenDictionary.updateValue(token(.roundBracketClose), forKey: .string(")"))
    codeTokenDictionary.updateValue(token(.squareBracketOpen), forKey: .string("["))
    codeTokenDictionary.updateValue(token(.squareBracketClose), forKey: .string("]"))
    codeTokenDictionary.updateValue(token(.curlyBracketOpen), forKey: .string("{"))
    codeTokenDictionary.updateValue(token(.curlyBracketClose), forKey: .string("}"))
    if let lexeme = stringRegexp { codeTokenDictionary.updateValue(token(.string), forKey: .pattern(lexeme)) }
    if let lexeme = characterRegexp { codeTokenDictionary.updateValue(token(.character), forKey: .pattern(lexeme)) }
    if let lexeme = numberRegexp { codeTokenDictionary.updateValue(token(.number), forKey: .pattern(lexeme)) }
    if let lexeme = singleLineComment {
      codeTokenDictionary.updateValue(token(Token.singleLineComment), forKey: .string(lexeme))
    }
    if let lexemes = nestedComment {
      codeTokenDictionary.updateValue((token: .nestedCommentOpen, transition: incNestedComment),
                                      forKey: .string(lexemes.open))
      codeTokenDictionary.updateValue((token: .nestedCommentClose, transition: decNestedComment),
                                      forKey: .string(lexemes.close))
    }
    if let lexeme = identifierRegexp { codeTokenDictionary.updateValue(token(Token.identifier(nil)),
                                                                       forKey: .pattern(lexeme)) }
    for reserved in reservedIdentifiers {
      codeTokenDictionary.updateValue(token(.keyword), forKey: .word(reserved))
    }

    tokenDictionary.updateValue(codeTokenDictionary, forKey: .tokenisingCode)

    // Populate the token dictionary for the comment state (tokenising within a nested comment)
    //
    var commentTokenDictionary = [TokenPattern: TokenAction]()

    if let lexemes = nestedComment {
      commentTokenDictionary.updateValue((token: .nestedCommentOpen, transition: incNestedComment),
                                         forKey: .string(lexemes.open))
      commentTokenDictionary.updateValue((token: .nestedCommentClose, transition: decNestedComment),
                                         forKey: .string(lexemes.close))
    }

    tokenDictionary.updateValue(commentTokenDictionary, forKey: .tokenisingComment)

    return tokenDictionary
  }
}
