//
//  HaskellConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/01/2023.
//

import Foundation
import RegexBuilder


private let haskellReservedIds =
  ["case", "class", "data", "default", "deriving", "do", "else", "foreign", "if", "import", "in", "infix", "infixl",
   "infixr", "instance", "let", "module", "newtype", "of", "then", "type", "where"]

extension LanguageConfiguration {

  /// Language configuration for Haskell (including GHC extensions)
  ///
  public static func haskell(_ languageService: LanguageServiceBuilder? = nil) -> LanguageConfiguration {
    let numberRegex = Regex {
      optNegation
      ChoiceOf {
        Regex{ /0[bB]/; binaryLit }
        Regex{ /0[oO]/; octalLit }
        Regex{ /0[xX]/; hexalLit }
        Regex{ /0[xX]/; hexalLit; "."; hexalLit; Optionally{ hexponentLit } }
        Regex{ decimalLit; "."; decimalLit; Optionally{ exponentLit } }
        Regex{ decimalLit; exponentLit }
        decimalLit
      }
    }
    let identifierRegex = Regex {
      identifierHeadChar
      ZeroOrMore {
        ChoiceOf {
          identifierHeadChar
          identifierBodyChar
          "'"
        }
      }
    }
    return LanguageConfiguration(name: "Haskell",
                                 stringRegex: /\"(?:\\\\\"|[^\"])*+\"/,
                                 characterRegex: /'(?:\\\\'|[^']|\\\\[^']*+)'/,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "{-", close: "-}"),
                                 identifierRegex: identifierRegex,
                                 reservedIdentifiers: haskellReservedIds,
                                 languageService: languageService)
  }
}
