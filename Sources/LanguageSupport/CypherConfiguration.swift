//
//  CypherConfiguration.swift
//
//
//  Created by Carlo Rapisarda on 2024-12-21.
//

import Foundation
import RegexBuilder

extension LanguageConfiguration {
    
    public static func cypher(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
        
        // Number Regex
        // Optional + or -, then digits, optional decimal, optional exponent
        let numberRegex: Regex<Substring> = Regex {
            Optionally {
                ChoiceOf {
                    "+"
                    "-"
                }
            }
            OneOrMore(.digit)
            Optionally {
                "."
                OneOrMore(.digit)
            }
            Optionally {
                ChoiceOf {
                    "e"
                    "E"
                }
                Optionally {
                    ChoiceOf {
                        "+"
                        "-"
                    }
                }
                OneOrMore(.digit)
            }
        }
        
        // Identifier Regex
        // Plain identifiers: start with letter or underscore, then letters, digits, underscores
        let alphaOrUnderscore = ChoiceOf {
            "a"..."z"
            "A"..."Z"
            "_"
        }
        let alphaNumOrUnderscore = ChoiceOf {
            "a"..."z"
            "A"..."Z"
            "0"..."9"
            "_"
        }
        
        // Plain (unquoted) identifier
        let plainIdentifierRegex: Regex<Substring> = Regex {
            alphaOrUnderscore
            ZeroOrMore {
                alphaNumOrUnderscore
            }
        }
        
        // Backtick-quoted identifier: everything except backticks
        let quotedIdentifierRegex: Regex<Substring> = Regex {
            "`"
            ZeroOrMore {
                NegativeLookahead {
                    "`"
                }
                // Match any character that is not a backtick
                CharacterClass.any
            }
            "`"
        }
        
        // Combine both unquoted and backtick-quoted
        let identifierRegex: Regex<Substring> = Regex {
            ChoiceOf {
                plainIdentifierRegex
                quotedIdentifierRegex
            }
        }
        
        // String Regex (single or double quoted, with doubled quotes to escape)
        // Single-quoted strings
        let singleQuotedString: Regex<Substring> = Regex {
            "'"
            ZeroOrMore {
                ChoiceOf {
                    // Two single-quotes in a row => escaped quote
                    Regex {
                        "'"
                        "'"
                    }
                    // Otherwise, any character except a single quote
                    Regex {
                        NegativeLookahead { "'" }
                        CharacterClass.any
                    }
                }
            }
            "'"
        }
        
        // Double-quoted strings
        let doubleQuotedString: Regex<Substring> = Regex {
            "\""
            ZeroOrMore {
                ChoiceOf {
                    // Two double-quotes in a row => escaped quote
                    Regex {
                        "\""
                        "\""
                    }
                    // Otherwise, any character except a double quote
                    Regex {
                        NegativeLookahead { "\"" }
                        CharacterClass.any
                    }
                }
            }
            "\""
        }
        
        // Combine single-quoted or double-quoted into one string pattern
        let cypherStringRegex: Regex<Substring> = Regex {
            ChoiceOf {
                singleQuotedString
                doubleQuotedString
            }
        }
        
        // Comment Syntax
        // Single-line: "//", nested: /* ... */
        let singleLineComment = "//"
        let nestedComment = (open: "/*", close: "*/")
        
        // Keywords (case-insensitive)
        let cypherReservedIdentifiers = [
            "all", "alter", "and", "as", "asc", "ascending",
            "by", "call", "case", "commit", "contains", "create",
            "delete", "desc", "descending", "detach", "distinct", "drop",
            "else", "end", "ends", "exists", "false", "fieldterminator",
            "filter", "in", "is", "limit", "load", "csv", "match",
            "merge", "not", "null", "on", "optional", "or", "order",
            "remove", "return", "skip", "start", "then", "true", "union",
            "unique", "unwind", "using", "when", "where", "with", "xor"
        ]
        
        // Operator Regex
        // We highlight multi-char and single-char operators.
        let operatorRegex: Regex<Substring> = Regex {
            ChoiceOf {
                "<>"
                "<="
                ">="
                "=~"
                "="
                "<"
                ">"
                "+"
                "-"
                "*"
                "/"
                "%"
                "^"
                "!"
            }
        }
        
        return LanguageConfiguration(
            name: "Cypher",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            caseInsensitiveReservedIdentifiers: true,
            stringRegex: cypherStringRegex,
            characterRegex: nil,
            numberRegex: numberRegex,
            singleLineComment: singleLineComment,
            nestedComment: nestedComment,
            identifierRegex: identifierRegex,
            operatorRegex: operatorRegex,
            reservedIdentifiers: cypherReservedIdentifiers,
            reservedOperators: [],
            languageService: languageService
        )
    }
}
