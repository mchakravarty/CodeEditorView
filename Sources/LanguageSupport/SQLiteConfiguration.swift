//
//  SQLiteConfiguration.swift
//
//
//  Created by Ben Barnett on 07/11/2024.
//

import Foundation
import RegexBuilder

extension LanguageConfiguration {
  
  public static func sqlite(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
    
    // https://www.sqlite.org/syntax/numeric-literal.html
    let numberRegex: Regex<Substring> = Regex {
      Optionally("-")
      ChoiceOf {
        Regex { /0[xX]/; hexalLit }
        Regex { "."; decimalLit; Optionally { exponentLit } }
        Regex { decimalLit; "."; decimalLit; Optionally { exponentLit } }
        Regex { decimalLit; exponentLit }
        decimalLit
      }
    }
    let plainIdentifierRegex: Regex<Substring> = Regex {
      sqliteIdentifierHeadCharacters
      ZeroOrMore {
        sqliteIdentifierCharacters
      }
    }
    let identifierRegex = Regex {
      ChoiceOf {
        plainIdentifierRegex
        Regex { "\""; plainIdentifierRegex; "\"" }
        Regex { "["; plainIdentifierRegex; "]" }
        Regex { "`"; plainIdentifierRegex; "`" }
      }
    }
      .matchingSemantics(.unicodeScalar)
    
    return LanguageConfiguration(name: "SQLite",
                                 supportsSquareBrackets: false,
                                 supportsCurlyBrackets: false,
                                 caseInsensitiveReservedIdentifiers: true,
                                 stringRegex: /'(?:''|[^'])*+'/,
                                 characterRegex: nil,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "/*", close: "*/"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: nil,
                                 reservedIdentifiers: sqliteReservedIdentifiers,
                                 reservedOperators: sqliteReservedOperators,
                                 languageService: languageService)
  }
  
  // See `sqlite3CtypeMap` in:
  // https://sqlite.org/src/file?name=ext/misc/normalize.c&ci=trunk
  private static let sqliteIdentifierHeadCharacters: CharacterClass = CharacterClass(
    "a"..."z",
    "A"..."Z",
    .anyOf("_"),
    "\u{80}" ... "\u{10FFFF}"
  )
  
  private static let sqliteIdentifierCharacters: CharacterClass = CharacterClass(
    sqliteIdentifierHeadCharacters,
    "0"..."9",
    .anyOf("\u{24}")
  )
  
  // https://sqlite.org/lang_keywords.html
  private static let sqliteReservedIdentifiers = [
    "abort",
    "action",
    "add",
    "after",
    "all",
    "alter",
    "always",
    "analyze",
    "and",
    "as",
    "asc",
    "attach",
    "autoincrement",
    "before",
    "begin",
    "between",
    "by",
    "cascade",
    "case",
    "cast",
    "check",
    "collate",
    "column",
    "commit",
    "conflict",
    "constraint",
    "create",
    "cross",
    "current",
    "current_date",
    "current_time",
    "current_timestamp",
    "database",
    "default",
    "deferrable",
    "deferred",
    "delete",
    "desc",
    "detach",
    "distinct",
    "do",
    "drop",
    "each",
    "else",
    "end",
    "escape",
    "except",
    "exclude",
    "exclusive",
    "exists",
    "explain",
    "fail",
    "filter",
    "first",
    "following",
    "for",
    "foreign",
    "from",
    "full",
    "generated",
    "glob",
    "group",
    "groups",
    "having",
    "if",
    "ignore",
    "immediate",
    "in",
    "index",
    "indexed",
    "initially",
    "inner",
    "insert",
    "instead",
    "intersect",
    "into",
    "is",
    "isnull",
    "join",
    "key",
    "last",
    "left",
    "like",
    "limit",
    "match",
    "materialized",
    "natural",
    "no",
    "not",
    "nothing",
    "notnull",
    "null",
    "nulls",
    "of",
    "offset",
    "on",
    "or",
    "order",
    "others",
    "outer",
    "over",
    "partition",
    "plan",
    "pragma",
    "preceding",
    "primary",
    "query",
    "raise",
    "range",
    "recursive",
    "references",
    "regexp",
    "reindex",
    "release",
    "rename",
    "replace",
    "restrict",
    "returning",
    "right",
    "rollback",
    "row",
    "rows",
    "savepoint",
    "select",
    "set",
    "table",
    "temp",
    "temporary",
    "then",
    "ties",
    "to",
    "transaction",
    "trigger",
    "unbounded",
    "union",
    "unique",
    "update",
    "using",
    "vacuum",
    "values",
    "view",
    "virtual",
    "when",
    "where",
    "window",
    "with",
    "without",
  ]
  
  // https://www.sqlite.org/lang_expr.html#operators_and_parse_affecting_attributes
  private static let sqliteReservedOperators = [
    "~", "+", "-",
    "||", "->", "->>",
    "*", "/", "%",
    "+", "-",
    "&", "|", "<<", ">>",
    "<", ">", "<=", ">=",
    "=", "==", "<>", "!=",
  ]
  
  
}
