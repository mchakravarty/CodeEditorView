//
//  LuauConfiguration.swift
//  MacSploit
//
//  Created by Karl Ehrlich on 02/09/2025.
//

import Foundation
import RegexBuilder


private let luauReservedIdentifiers =
  ["and", "break", "continue", "do", "else", "elseif", "end", "export",
   "false", "for", "function", "if", "in", "local", "nil", "not", "or",
   "repeat", "return", "then", "true", "type", "until", "while"]

private let luauReservedOperators =
  ["+", "-", "*", "/", "%", "^", "#", "==", "~=", "<=", ">=", "<", ">",
   "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "..", "..."]


extension LanguageConfiguration {

  /// Language configuration for Luau
  ///
  public static func luau(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
    let numberRegex: Regex<Substring> = Regex {
      optNegation
      ChoiceOf {
        // Decimal literal (integer or float)
        Regex { decimalLit; "."; decimalLit; Optionally { exponentLit } }
        Regex { decimalLit; exponentLit }
        decimalLit
      }
    }

    let plainIdentifierRegex: Regex<Substring> = Regex {
      identifierHeadCharacters
      ZeroOrMore {
        identifierCharacters
      }
    }

    let identifierRegex = Regex {
      ChoiceOf {
        plainIdentifierRegex
      }
    }

    let operatorRegex = Regex {
      ChoiceOf {
        Regex {
          operatorHeadCharacters
          ZeroOrMore {
            operatorCharacters
          }
        }
        Regex {
          "."
          OneOrMore {
            CharacterClass(operatorCharacters, .anyOf("."))
          }
        }
      }
    }

    return LanguageConfiguration(name: "Luau",
                                 supportsSquareBrackets: true,
                                 supportsCurlyBrackets: true,
                                 stringRegex: /"(?:\\"|[^"])*+"|\'(?:\\'|[^'])*+'/,
                                 characterRegex: nil,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "--[[", close: "]]"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: luauReservedIdentifiers,
                                 reservedOperators: luauReservedOperators,
                                 languageService: languageService)
  }
}
