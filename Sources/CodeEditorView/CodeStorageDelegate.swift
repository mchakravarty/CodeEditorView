//
//  CodeStorageDelegate.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//
//  'NSTextStorageDelegate' for code views compute, collect, store, and update additional information about the text
//  stored in the 'NSTextStorage' that they serve. This is needed to quickly navigate the text (e.g., at which character
//  position does a particular line start) and to support code-specific rendering (e.g., syntax highlighting).

import SwiftUI


// Custom token attributes
//
extension NSAttributedString.Key {

  /// Custom attribute marking comment ranges.
  ///
  static let comment = NSAttributedString.Key("comment")

  /// Custom attribute marking lexical tokens.
  ///
  static let token = NSAttributedString.Key("token")
}

/// The supported comment styles.
///
enum CommentStyle {
  case singleLineComment
  case nestedComment
}

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  let language:     LanguageConfiguration
  let lexemeRegexp: NSRegularExpression?    // cache the regular expression for token matching

  private(set) var lineMap = LineMap<Void>(string: "")

  init(with language: LanguageConfiguration) {
    self.language     = language
    self.lexemeRegexp = NSMutableAttributedString.regularExpression(for: language.tokenDictionary)
    super.init()
  }

  func textStorage(_ textStorage: NSTextStorage,
                   willProcessEditing editedMask: NSTextStorage.EditActions,
                   range editedRange: NSRange,  // Apple docs are incorrect here: this is the range *after* editing
                   changeInLength delta: Int)
  {
    // If only attributes change, the line map and syntax highlighting remains the same => nothing for us to do
    guard editedMask.contains(.editedCharacters) else { return }

    lineMap.updateAfterEditing(string: textStorage.string, range: editedRange, changeInLength: delta)

    // We need to extend the range to account for lexemes that extend beyond the currently edited range. In principle,
    // going to the previous and next word boundary (whitespace character) would be sufficient, but it doesn't seem as
    // straightforward to find those boundaries as finding the line boundaries.
    let extendedRange = (textStorage.string as NSString).lineRange(for: editedRange)
    tokeniseAttributesFor(range: extendedRange, in: textStorage)
  }
}

extension CodeStorageDelegate {

  /// Tokenise the substring of the given text storage that contains the specified lines and set token attributes as
  /// needed.
  ///
  func tokeniseAttributesFor(range: NSRange, in textStorage: NSTextStorage) {
    guard let regexp = lexemeRegexp else { return }

    // Set the token attribute in range.
    textStorage.determineAndSetTokenAttribute(attribute: .token,
                                              tokenMap: language.tokenDictionary,
                                              with: regexp,
                                              in: range)

    // Collect all tokens in range.
    var tokens = Array<(token: LanguageConfiguration.Token, range: NSRange)>()
    textStorage.enumerateAttribute(.token, in: range, options: []){ (value, range, _) in

      if let tokenValue = value as? LanguageConfiguration.Token { tokens.append((token: tokenValue, range: range)) }
    }

    // TODO: we need a flag in the line map to indicate for every line whether it is an inner comment line; i.e., a line
    //       where all characters are within a nested comment that neither starts not stops on that very line. If we
    //       edit such lines, we need to mark everything with the appropriate comment attribute, but we want to do that
    //       locally without l0oking at the whole —possibly long— comment.

    // Make sure the comment attribute is properly set in the edited range and determine the highlighting range, which
    // may be larger as (new) comments may extent outside of the edited range,
    textStorage.removeAttribute(.comment, range: range)
    let highlightingRange = attributeAllCommentedCharacters(range: range, with: tokens, in: textStorage)
    textStorage.removeAttribute(.foregroundColor, range: highlightingRange)

//    textStorage.enumerateAttribute(.comment, in: range, options: []){ (value, range, _) in
//
//    }

//    fixHighlightingAttributes(lines: highlightingLines, in: textStorage)
    fixHighlightingAttributes(range: highlightingRange, in: textStorage)
    // FIXME: if `affectedLines` wider than `lines`, don't we have to explicitly tigger a redraw for the rectangles covering the extra lines??
  }

  /// Ensure that all characters that are commented out in the given range, receive the `.comment` attributes. We assume
  /// that the `.token` attribute has been properly set on all comment-related lexemes.
  ///
  /// - Parameters:
  ///   - range: Range of characters to consider.
  ///   - tokens: Array of the tokens identified in the given range.
  ///   - textStorage: The text storage containing the text to be attributed.
  /// - Returns: Cheracter range extended, such it encompasses all characters whose `.comment` status was affected by
  ///            by the currently processed edit.
  ///
  func attributeAllCommentedCharacters(range: NSRange,
                                       with tokens: Array<(token: LanguageConfiguration.Token, range: NSRange)>,
                                       in textStorage: NSTextStorage) -> NSRange
  {
    var extendedRange = range

    // TODO: handle nested comments

    // For all single line comment tokens, set the comment attribute up to the end of the line on which the token
    // appears and ensure that the `extendedRange` reaches up to the end of that line. (We don't care about multiple
    // tokens per line as they don't affect the attributes to be set.)
    for token in (tokens.filter{ $0.token == .singleLineComment }) {

      let commentStart   = token.range.location
      if let commentLine = lineMap.lineOf(index: commentStart),
         let lineRange   = lineMap.lookup(line: commentLine)?.range
      {

        let commentRange = NSRange(location: commentStart, length: NSMaxRange(lineRange) - commentStart)
        textStorage.addAttribute(.comment, value: CommentStyle.singleLineComment, range: commentRange)
        extendedRange = NSUnionRange(extendedRange, commentRange)

      }
    }
    return extendedRange
  }

  /// Based on the token attributes, set the highlighting attributes of the characters in the given line range.
  ///
//  func fixHighlightingAttributes(lines: Range<Int>, in textStorage: NSTextStorage) {
  func fixHighlightingAttributes(range: NSRange, in textStorage: NSTextStorage) {

//    let range = lineMap.charRangeOf(lines: lines)
    textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
    textStorage.enumerateAttribute(.comment, in: range){ (optionalValue, attrRange, _) in

      if optionalValue != nil { textStorage.addAttribute(.foregroundColor, value: UIColor.darkGray, range: attrRange) }

    }
  }
}

