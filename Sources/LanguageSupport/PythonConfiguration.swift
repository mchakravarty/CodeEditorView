//
//  File.swift
//  CodeEditorView
//
//  Created by Phineas Guo on 2025/6/4.
//

import Foundation
import RegexBuilder

extension LanguageConfiguration{
    
    
    
    public static func python(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
        
        
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
        
        let plainIdentifierRegex: Regex<Substring> = Regex {
          identifierHeadCharacters
          ZeroOrMore {
            identifierCharacters
          }
        }
        
        let identifierRegex = Regex {
          ChoiceOf {
            plainIdentifierRegex
            Regex { "@"; decimalLit }
          }
        }
        
        let reservedIdentifiers = [
            "False", "None", "True", "and", "as", "assert", "async", "await","break", "class", "continue", "def", "del", "elif", "else", "except","finally", "for", "from", "global", "if", "import", "in", "is", "lambda","nonlocal", "not", "or", "pass", "raise", "return", "try", "while","with", "yield"
        ]
        
        let reservedOperators = [
            "+", "-", "*", "/", "//", "%", "**","==", "!=", ">", "<", ">=", "<=","=", "+=", "-=", "*=", "/=", "//=", "%=", "**=", "&=", "|=", "^=", "<<=", ">>=","and", "or", "not","&", "|", "^", "~", "<<", ">>","in", "not in","is", "is not", "@", ":"
        ]
        
        return LanguageConfiguration(
            name: "Python",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: false,
            stringRegex: /\"(?:\\\"|[^\"])*+\"/,
            characterRegex: /'(?:\\'|[^']|\\[^']*+)'/,
            numberRegex: numberRegex,
            singleLineComment: "#",
            nestedComment: (open: "'''" ,close: "'''"),
            identifierRegex: identifierRegex,
            operatorRegex: operatorRegex,
            reservedIdentifiers: reservedIdentifiers,
            reservedOperators: reservedOperators,
            languageService: languageService
        )
    }
    
    
    
    
    
    
    
}
