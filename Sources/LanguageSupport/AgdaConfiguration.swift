//
//  AgdaConfiguration.swift
//
//
//  Created by Manuel M T Chakravarty on 31/05/2023.
//
//  Currently following Agda 2.6.4.4
//

import Foundation
import RegexBuilder


private let agdaReservedIds =
  ["abstract", "codata", "coinductive", "constructor", "data", "do", "eta-equality", "field", "forall", "import", "in",
   "inductive", "infix", "infixl", "infixr", "instance", "interleaved", "let", "macro", "module", "mutual",
   "no-eta-equality", "open", "overlap", "pattern", "postulate", "primitive", "private", "quote", "quoteTerm", "record",
   "rewrite", "syntax", "tactic", "unquote", "unquoteDecl", "unquoteDef", "variable", "where", "with", "opaque",
   "unfolding", "using", "hiding", "renaming", "public"]
private let agdaReservedOperator =
  ["=", "|", "->", "→", ":", "?", "\\", "λ", "∀", "..", "..."]

extension LanguageConfiguration {

  /// Language configuration for Agda
  ///
  public static func agda(_ languageService: LanguageServiceBuilder? = nil) -> LanguageConfiguration {
    let nameSeparator = CharacterClass(.anyOf(".;{}()@\""), .whitespace)
    let numberRegex = Regex {
      optNegation
      ChoiceOf {
        Regex{ /0[xX]/; hexalLit }
        Regex{ decimalLit; "."; decimalLit; Optionally{ exponentLit } }
        Regex{ decimalLit; exponentLit }
        decimalLit
      }
    }
    let agdaNamePartHeadChar: CharacterClass = .any.subtracting(.anyOf("_'")).subtracting(nameSeparator),
        agdaNamePartBodyChar: CharacterClass = CharacterClass(agdaNamePartHeadChar, .anyOf("'"))
    let namePart        = Regex { agdaNamePartHeadChar; ZeroOrMore{ agdaNamePartBodyChar } },
        identifierRegex = Regex {
          Optionally { /_/ }
          OneOrMore { Regex { namePart; /_/ } }
          namePart
        }
    return LanguageConfiguration(name: "Agda",
                                 stringRegex: /\"(?:\\\"|[^\"])*+\"/,
                                 characterRegex: /'(?:\\'|[^']|\\[^']*+)'/,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "{-", close: "-}"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: nil,
                                 reservedIdentifiers: agdaReservedIds,
                                 reservedOperators: agdaReservedOperator,
                                 languageService: languageService)
  }
}
