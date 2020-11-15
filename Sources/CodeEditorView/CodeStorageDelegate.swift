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

/// Information that is tracked on a line by line basis in the line map.
///
struct LineInfo {
  var roundBracketDiff:  Int  // increase or decrease of the nesting level of round brackets on this line
  var squareBracketDiff: Int  // increase or decrease of the nesting level of square brackets on this line
  var curlyBracketDiff:  Int  // increase or decrease of the nesting level of curly brackets on this line
}

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  // TODO: we need two regular expressions: one regular one and one that tokenizes inside a (nested) comment

  let language:  LanguageConfiguration
  let tokeniser: Tokeniser<LanguageConfiguration.Token>?    // cache the tokeniser for token matching

  private(set) var lineMap = LineMap<LineInfo>(string: "")

  init(with language: LanguageConfiguration) {
    self.language  = language
    self.tokeniser = NSMutableAttributedString.tokeniser(for: language.tokenDictionary)
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
    guard let tokeniser = tokeniser else { return }

    // Set the token attribute in range.
    textStorage.tokeniseAndSetTokenAttribute(attribute: .token,
                                             with: tokeniser,
                                             in: range)

    // For all lines in range, collect the tokens line by line
    let lines           = lineMap.linesContaining(range: range)
    var linesWithTokens = Array<(lineRange: NSRange,
                                 tokens: Array<(token: LanguageConfiguration.Token, range: NSRange)>)>()
    for line in lines {

      if let lineRange = lineMap.lookup(line: line)?.range {

        // Remove any existing `.comment` attribute on this line
        textStorage.removeAttribute(.comment, range: lineRange)

        // Collect all tokens on this line.
        // (NB: In the block, we are not supposed to mutate outside the attribute range; hence, we only collect tokens.)
        var tokens = Array<(token: LanguageConfiguration.Token, range: NSRange)>()
        textStorage.enumerateAttribute(.token, in: lineRange, options: []){ (value, range, _) in

          if let tokenValue = value as? LanguageConfiguration.Token { tokens.append((token: tokenValue, range: range)) }
        }
        linesWithTokens.append((lineRange: lineRange, tokens: tokens))

        // FIXME: this has to change with nested comments
        var lineInfo = LineInfo(roundBracketDiff: 0, squareBracketDiff: 0, curlyBracketDiff: 0)
        tokenLoop: for token in tokens {

          switch token.token {

          case .roundBracketOpen:
            lineInfo.roundBracketDiff += 1

          case .roundBracketClose:
            lineInfo.roundBracketDiff -= 1

          case .squareBracketOpen:
            lineInfo.squareBracketDiff += 1

          case .squareBracketClose:
            lineInfo.squareBracketDiff -= 1

          case .curlyBracketOpen:
            lineInfo.curlyBracketDiff += 1

          case .curlyBracketClose:
            lineInfo.curlyBracketDiff -= 1

          case .singleLineComment:  // set comment attribute from token start token to the end of this line
            let commentStart = token.range.location,
                commentRange = NSRange(location: commentStart, length: NSMaxRange(lineRange) - commentStart)
            textStorage.addAttribute(.comment, value: CommentStyle.singleLineComment, range: commentRange)
            break tokenLoop           // the rest of the tokens are ignored as they are commented out

          default:
            break
          }
        }
        lineMap.setInfoOf(line: line, to: lineInfo)
      }
    }

    /*
    // FIXME: the following interacts with nested comments as the comment tokens can cancel each other (in some configurations)

    // Add `.comment` attribute for single line comments and calculate brackets diff.
    for lineWithToken in linesWithTokens {

    }

//----

    // Collect all tokens in range.
    var tokens = Array<(token: LanguageConfiguration.Token, range: NSRange)>()
    textStorage.enumerateAttribute(.token, in: range, options: []){ (value, range, _) in

      if let tokenValue = value as? LanguageConfiguration.Token { tokens.append((token: tokenValue, range: range)) }
    }

//    let lines = lineMap.linesContaining(range: range)

    // TODO: we need a flag in the line map to indicate for every line whether it is an inner comment line; i.e., a line
    //       where all characters are within a nested comment that neither starts not stops on that very line. If we
    //       edit such lines, we need to mark everything with the appropriate comment attribute, but we want to do that
    //       locally without l0oking at the whole —possibly long— comment.

    // Make sure the comment attribute is properly set in the edited range and determine the highlighting range, which
    // may be larger as (new) comments may extent outside of the edited range,
    textStorage.removeAttribute(.comment, range: range)
    let highlightingRange = attributeAllCommentedCharacters(range: range, with: tokens, in: textStorage)

 */
//    textStorage.removeAttribute(.foregroundColor, range: highlightingRange)
    textStorage.removeAttribute(.foregroundColor, range: range)

//    fixHighlightingAttributes(lines: highlightingLines, in: textStorage)
    fixHighlightingAttributes(range: range, in: textStorage)
    // FIXME: if `affectedLines` wider than `lines`, don't we have to explicitly tigger a redraw for the rectangles covering the extra lines??
  }

  /*
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
 */

  /// Based on the token attributes, set the highlighting attributes of the characters in the given line range.
  ///
//  func fixHighlightingAttributes(lines: Range<Int>, in textStorage: NSTextStorage) {
  func fixHighlightingAttributes(range: NSRange, in textStorage: NSTextStorage) {

//    let range = lineMap.charRangeOf(lines: lines)
    textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: range)
    textStorage.enumerateAttribute(.token, in: range){ (optionalValue, attrRange, _) in

      if let value = optionalValue as? LanguageConfiguration.Token, value == .string {
        textStorage.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: attrRange)
      }
    }
    textStorage.enumerateAttribute(.comment, in: range){ (optionalValue, attrRange, _) in

      if optionalValue != nil { textStorage.addAttribute(.foregroundColor, value: UIColor.darkGray, range: attrRange) }
    }
  }
}

