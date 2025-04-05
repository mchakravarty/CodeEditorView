//
//  CabalConfiguration.swift
//  CodeEditorView
//
//  Created by Manuel M T Chakravarty on 05/04/2025.
//
//  Cabal configuration files: https://www.haskell.org/cabal/

import Foundation
import RegexBuilder


private let cabalReservedIds: [String] = []
private let cabalReservedOperators     = [":"]

extension LanguageConfiguration {

  /// Language configuration for Cabal configurations
  ///
  public static func cabal(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
    let numberRegex = Regex {
      optNegation
      ChoiceOf {
        Regex{ decimalLit; ZeroOrMore { "."; decimalLit } }
      }
    }
    let identifierRegex = Regex {
      identifierHeadCharacters
      ZeroOrMore {
        CharacterClass(identifierCharacters, .anyOf("'-"))
      }
      /\:/
    }
    let symbolCharacter = CharacterClass(.anyOf("&<=>|~")),
        operatorRegex   = Regex {
          symbolCharacter
          ZeroOrMore { symbolCharacter }
        }
    return LanguageConfiguration(name: "Cabal",
                                 supportsSquareBrackets: false,
                                 supportsCurlyBrackets: false,
                                 indentationSensitiveScoping: true,
                                 stringRegex: /\"/,
                                 characterRegex: /'/,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "{-", close: "-}"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: cabalReservedIds,
                                 reservedOperators: cabalReservedOperators,
                                 languageService: languageService)
  }
}
