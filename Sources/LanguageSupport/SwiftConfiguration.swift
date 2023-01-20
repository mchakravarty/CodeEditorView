//
//  SwiftConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/01/2023.
//

import Foundation


private let swiftReservedIds =
  ["actor", "associatedtype", "async", "await", "as", "break", "case", "catch", "class", "continue", "default", "defer",
   "deinit", "do", "else", "enum", "extension", "fallthrough", "fileprivate", "for", "func", "guard", "if", "import",
   "init", "inout", "internal", "in", "is", "let", "operator", "precedencegroup", "private", "protocol", "public",
   "repeat", "rethrows", "return", "self", "static", "struct", "subscript", "super", "switch", "throws", "throw", "try",
   "typealias", "var", "where", "while"]

extension LanguageConfiguration {

  /// Language configuration for Swift
  ///
  public static func swift(_ languageService: LanguageServiceBuilder? = nil) -> LanguageConfiguration {
    return LanguageConfiguration(name: "Swift",
                                 stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                 characterRegexp: nil,
                                 numberRegexp:
                                  optNegation +
                                 group(alternatives([
                                  "0b" + binaryLit,
                                  "0o" + octalLit,
                                  "0x" + hexalLit,
                                  "0x" + hexalLit + "\\." + hexalLit + hexponentLit + "?",
                                  decimalLit + "\\." + decimalLit + exponentLit + "?",
                                  decimalLit + exponentLit,
                                  decimalLit
                                 ])),
                                 singleLineComment: "//",
                                 nestedComment: (open: "/*", close: "*/"),
                                 identifierRegexp:
                                  alternatives([
                                    identifierHeadChar +
                                    group(alternatives([
                                      identifierHeadChar,
                                      identifierBodyChar,
                                    ])) + "*",
                                    "`" + identifierHeadChar +
                                    group(alternatives([
                                      identifierHeadChar,
                                      identifierBodyChar,
                                    ])) + "*`",
                                    "\\\\$" + decimalLit,
                                    "\\\\$" + identifierHeadChar +
                                    group(alternatives([
                                      identifierHeadChar,
                                      identifierBodyChar,
                                    ])) + "*"
                                  ]),
                                 reservedIdentifiers: swiftReservedIds,
                                 languageService: languageService)
  }
}
