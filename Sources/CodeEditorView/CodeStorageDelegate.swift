//
//  CodeStorageDelegate.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//
//  'NSTextStorageDelegate' for code views compute, collect, store, and update additional information about the text
//  stored in the 'NSTextStorage' that they serve. This is needed to quickly navigate the text (e.g., at which character
//  position does a particular line start) and to support code-specific rendering (e.g., syntax highlighting).

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


// Custom token attributes
//
extension NSAttributedString.Key {

  /// Custom attribute marking comment ranges.
  ///
  static let comment = NSAttributedString.Key("comment")
}

/// The supported comment styles.
///
enum CommentStyle {
  case singleLineComment
  case nestedComment
}

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  let language: LanguageConfiguration

  private(set) var lineMap = LineMap<Void>(string: "")

  init(with language: LanguageConfiguration) {
    self.language = language
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

    // TODO: get the range of lines that are affected by the change; retokenize; and add token class attributes (still to be defined) that form the basis for the temporary attributes generated for syntax highlighting
    let lines = lineMap.linesContaining(range: editedRange)
    fixTokenAttributesFor(lines: lines, in: textStorage)
  }
}

extension CodeStorageDelegate {

  /// Tokenise the substring of the given text storage that contains the specified lines and set token attributes as
  /// needed.
  ///
  func fixTokenAttributesFor(lines: Range<Int>, in textStorage: NSTextStorage) {

    var highlightingAffectedLines = lines

    for line in lines {

      let lineRange = lineMap.lookup(line: line)?.range ?? NSRange(location: 0, length: 0)
      textStorage.removeAttribute(.comment, range: lineRange)
      textStorage.removeAttribute(.foregroundColor, range: lineRange)

      if let commentLexeme = language.singleLineComment,
         let position = textStorage.string.range(of: commentLexeme, range: Range(lineRange, in: textStorage.string))
      {

        let startIndex = position.lowerBound.utf16Offset(in: textStorage.string)
        textStorage.addAttributes([.comment: CommentStyle.singleLineComment],
                                  range: NSRange(location: startIndex, length: NSMaxRange(lineRange) - startIndex))

      }
    }

    fixHighlightingAttributes(lines: highlightingAffectedLines, in: textStorage)
    // FIXME: if `affectedLines` wider than `lines`, don't we have to explicitly tigger a redraw for the rectangles covering the extra lines??
  }

  /// Based on the token attributes, set the highlighting attributes of the characters in the given line range.
  ///
  func fixHighlightingAttributes(lines: Range<Int>, in textStorage: NSTextStorage) {

    let charRange = lineMap.charRangeOf(lines: lines)
    textStorage.addAttribute(.foregroundColor, value: UIColor.label, range: charRange)
    textStorage.enumerateAttribute(.comment, in: charRange){ (optionalValue, attrRange, _) in

      if optionalValue != nil { textStorage.addAttribute(.foregroundColor, value: UIColor.darkGray, range: attrRange) }

    }
  }
}
