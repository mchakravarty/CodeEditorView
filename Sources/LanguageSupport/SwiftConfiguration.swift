//
//  SwiftConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/01/2023.
//

import Foundation
import RegexBuilder


private let swiftReservedIdentifiers =
  ["actor", "associatedtype", "async", "await", "as", "break", "case", "catch", "class", "continue", "default", "defer",
   "deinit", "do", "else", "enum", "extension", "fallthrough", "fileprivate", "for", "func", "guard", "if", "import",
   "init", "inout", "internal", "in", "is", "let", "operator", "precedencegroup", "private", "protocol", "public",
   "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super", "switch", "throws", "throw", "try",
   "typealias", "var", "where", "while", "#available", "#colorLiteral", "#else", "#elseif", "#endif", "#fileLiteral",
   "#if", "#imageLiteral", "#keyPath", "#selector", "#sourceLocation", "#unavailable"]
private let swiftReservedOperators =
  [".", ",", ":", ";", "=", "@", "#", "&", "->", "`", "?", "!"]

extension LanguageConfiguration {

  /// Language configuration for Swift
  ///
  public static func swift(_ languageService: LanguageServiceBuilder? = nil) -> LanguageConfiguration {
    let numberRegex: Regex<Substring> = Regex {
      optNegation
      ChoiceOf {
        Regex { /0b/; binaryLit }
        Regex { /0o/; octalLit }
        Regex { /0x/; hexalLit }
        Regex { /0x/; hexalLit; "."; hexalLit; Optionally { hexponentLit } }
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
        Regex { "`"; plainIdentifierRegex; "`" }
        Regex { "$"; decimalLit }
        Regex { "$"; plainIdentifierRegex }
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
    return LanguageConfiguration(name: "Swift",
                                 stringRegex: /\"(?:\\\"|[^\"])*+\"/,
                                 characterRegex: nil,
                                 numberRegex: numberRegex,
                                 singleLineComment: "//",
                                 nestedComment: (open: "/*", close: "*/"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: swiftReservedIdentifiers,
                                 reservedOperators: swiftReservedOperators,
                                 languageService: languageService)
  }
}
