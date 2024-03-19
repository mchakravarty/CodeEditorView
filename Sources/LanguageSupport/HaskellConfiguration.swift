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
private let haskellReservedOperators =
  ["..", ":", "::", "=", "\\", "|", "<-", "->", "@", "~", "=>"]

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
      identifierHeadCharacters
      ZeroOrMore {
        CharacterClass(identifierCharacters, .anyOf("'"))
      }
    }
    let symbolCharacter = CharacterClass(.anyOf("!#$%&⋆+./<=>?@\\^|-~:"),
                                         operatorHeadCharacters.subtracting(.anyOf("/=-+!*%<>&|^~?"))),
                                         // This is for the Unicode symbols, but the Haskell spec actually specifies "any Unicode symbol or punctuation".
        operatorRegex   = Regex {
          symbolCharacter
          ZeroOrMore { symbolCharacter }
        }
    return LanguageConfiguration(name: "Haskell",
                                 stringRegex: /\"(?:\\\"|[^\"])*+\"/,
                                 characterRegex: /'(?:\\'|[^']|\\[^']*+)'/,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "{-", close: "-}"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: haskellReservedIds,
                                 reservedOperators: haskellReservedOperators,
                                 languageService: languageService)
  }
}
