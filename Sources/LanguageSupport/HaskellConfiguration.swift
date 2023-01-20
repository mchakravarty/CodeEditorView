//
//  HaskellConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/01/2023.
//

import Foundation


private let haskellReservedIds =
  ["case", "class", "data", "default", "deriving", "do", "else", "foreign", "if", "import", "in", "infix", "infixl",
   "infixr", "instance", "let", "module", "newtype", "of", "then", "type", "where"]

extension LanguageConfiguration {

  /// Language configuration for Haskell (including GHC extensions)
  ///
  public static func haskell(_ languageService: LanguageServiceBuilder? = nil) -> LanguageConfiguration {
    return LanguageConfiguration(name: "Haskell",
                                 stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                 characterRegexp: "'(?:\\\\'|[^']|\\\\[^']*+)'",
                                 numberRegexp:
                                  optNegation +
                                 group(alternatives([
                                  "0[bB]" + binaryLit,
                                  "0[oO]" + octalLit,
                                  "0[xX]" + hexalLit,
                                  "0[xX]" + hexalLit + "\\." + hexalLit + hexponentLit + "?",
                                  decimalLit + "\\." + decimalLit + exponentLit + "?",
                                  decimalLit + exponentLit,
                                  decimalLit
                                 ])),
                                 singleLineComment: "--",
                                 nestedComment: (open: "{-", close: "-}"),
                                 identifierRegexp:
                                  identifierHeadChar +
                                 group(alternatives([
                                  identifierHeadChar,
                                  identifierBodyChar,
                                  "'"
                                 ])) + "*",
                                 reservedIdentifiers: haskellReservedIds,
                                 languageService: languageService)
  }
}
