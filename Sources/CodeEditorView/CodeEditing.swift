//
//  CodeEditing.swift
//  CodeEditorView
//
//  Created by Manuel M T Chakravarty on 06/01/2025.
//
//  This file implements common code editing operations.

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif


extension NSRange {
  
  /// Adjusts the selection represneted by `self` in accordance with replacing the characters in the given range with
  /// the given number of replacement characters.
  ///
  /// - Parameters:
  ///   - range: The range that is being replaced.
  ///   - delta: The number of characters in the replacement string.
  ///
  func adjustSelection(forReplacing range: NSRange, by length: Int) -> NSRange {

    let delta = length - range.length
    if let overlap = intersection(range) {

      if location <= range.location {

        if max >= range.max {
          // selection encompasses the whole replaced range
          return shifted(endBy: delta) ?? self
        } else {
          // selection overlaps with a proper prefix of the replaced range
          if range.length - overlap.length < -delta {
            // text shrinks sufficiently that the selection needs to shrink, too
            return shifted(endBy: -delta - (range.length - overlap.length)) ?? NSRange(location: location, length: 0)
          } else {
            return self
          }
        }

      } else {

        // selection overlaps with a proper suffix of the replaced range or is contained in the replaced range
        if range.length - overlap.length < -delta {
          // text shrinks sufficiently that the selection needs to shrink, too
          return shifted(endBy: -delta - (range.length - overlap.length)) ?? NSRange(location: location, length: 0)
        } else {
          return self
        }

      }

    } else {

      if location <= range.location {
        // selection is in front of the replaced text
        return self
      } else {
        // selection is behind the replaced text
        return shifted(by: delta) ?? self
      }
    }
  }
}

extension CodeView {

#if os(macOS)
  override func performKeyEquivalent(with event: NSEvent) -> Bool {

    if event.charactersIgnoringModifiers == "/"
        && event.modifierFlags.intersection([.command, .control, .option]) == .command
    {

      comment()
      return true

    } else {
      return super.performKeyEquivalent(with: event)
    }
  }
#endif
}

extension CodeView {
  
  /// Comment or uncomment the selection or multiple lines.
  ///
  /// For each selection range in the current selection, proceed as follows:
  ///
  /// 1. If the selection has zero length (it is an insertion point), comment or uncomment the line where the selection
  ///    is located.
  /// 2. If the selection has a length greater zero, but does not extend across a line end, enclose the selection in
  ///    nested comments or remove the nested comment brackets, if the selection is already enclosed in comments. In the
  ///    latter case, the selection may (partially) include the comment brackets. This is unless the selected range
  ///    totally or partially covers commented text. In that case, proceed as if the selection had zero length.
  /// 3. If the selection extends across multiple lines, comment all lines, unless the first and last line are already
  ///    commented. In the latter case, uncomment all commented lines.
  ///
  func comment() {
    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }

    // Determine whether the leading token on the given line is a single line comment token.
    func isCommented(line: Int) -> Bool {
      guard let theLine = codeStorageDelegate.lineMap.lookup(line: line) else { return false }

      return theLine.info?.tokens.first?.token == .singleLineComment
    }

    // Insert single line comment token at the start of the line.
    func comment(line: Int, with range: NSRange) -> NSRange {
      guard let theLine                 = codeStorageDelegate.lineMap.lookup(line: line),
            let singleLineCommentString = language.singleLineComment
      else { return range }

      // Insert single line comment
      let replacementRange = NSRange(location: theLine.range.location, length: 0)
      codeStorage.replaceCharacters(in: replacementRange, with: singleLineCommentString)
      return range.adjustSelection(forReplacing: replacementRange, by: singleLineCommentString.count)
    }
    
    // Remove leading single line comment token (if any).
    func uncomment(line: Int, with range: NSRange) -> NSRange {
      guard let theLine = codeStorageDelegate.lineMap.lookup(line: line) else { return range }

      if let firstToken = theLine.info?.tokens.first,
         firstToken.token == .singleLineComment,
         let tokenRange = firstToken.range.shifted(by: theLine.range.location)
      {

        codeStorage.deleteCharacters(in: tokenRange)
        return range.adjustSelection(forReplacing: tokenRange, by: 0)

      } else {
        return range
      }
    }

    // Determine whether the selection is fully enclosed in a bracketed comment on the given line. If so, return the
    // comment range (wrt to the whole document).
    func isCommentBracketed(range: NSRange, on line: Int) -> NSRange? {
      guard let theLine       = codeStorageDelegate.lineMap.lookup(line: line),
            let tokens        = theLine.info?.tokens,
            let commentRanges = theLine.info?.commentRanges,
            let localRange    = range.shifted(by: -theLine.range.location)
      else { return nil }

      for commentRange in commentRanges {
        if commentRange.intersection(localRange) == localRange
            && (tokens.contains{ $0.range.location == commentRange.location && $0.token == .nestedCommentOpen })
        {
          return commentRange.shifted(by: theLine.range.location)
        }
      }
      return nil
    }

    // Add comment brackets around the given range.
    func commentBracket(range: NSRange) -> NSRange {
      guard let (openString, closeString) = language.nestedComment else { return range }

      codeStorage.replaceCharacters(in: NSRange(location: range.max, length: 0), with: closeString)
      codeStorage.replaceCharacters(in: NSRange(location: range.location, length: 0), with: openString)
      return range.shifted(by: openString.count) ?? range
    }

    // Remove comment brackets at the ends of the given comment range.
    func uncommentBracket(range: NSRange, in commentRange: NSRange) -> NSRange {
      guard let (openString, closeString) = language.nestedComment else { return range }

      codeStorage.deleteCharacters(in: NSRange(location: commentRange.max - closeString.count,
                                               length: closeString.count))
      codeStorage.deleteCharacters(in: NSRange(location: commentRange.location, length: openString.count))
      let newCommentRange = commentRange.shifted(by: -openString.count)?.shifted(endBy: -closeString.count) ?? commentRange
      return (range.shifted(by: -openString.count) ?? range).intersection(newCommentRange) ?? range
    }

    textContentStorage.performEditingTransaction {

      // NB: It is crucial to process selected ranges in reverse order as any text change invalidates ranges in the line
      //     map after the change.
#if os(macOS)
      let ranges = selectedRanges.reversed()
#elseif os(iOS) || os(visionOS)
      let ranges = [NSValue(range: selectedRange)]
#endif
      var newSelected: [NSRange] = []
      for rangeAsValue in ranges {
        let range = rangeAsValue.rangeValue

        let lines = codeStorageDelegate.lineMap.linesContaining(range: range)
        guard let firstLine = lines.first else { continue }

        var newRange = range
        if range.length == 0 {

          // Case 1 of the specification
          newRange = if isCommented(line: firstLine) {
                       uncomment(line: firstLine, with: range)
                     } else {
                       comment(line: firstLine, with: range)
                     }

        } else if lines.count == 1 {

          // Case 2 of the specification
          guard let theLine = codeStorageDelegate.lineMap.lookup(line: firstLine)
          else {
            newSelected.append(range)
            continue
          }
          let lineLocation = range.location - theLine.range.location
          if let commentRange = isCommentBracketed(range: range, on: firstLine) {
            newRange = uncommentBracket(range: range, in: commentRange)
          } else {

            let partiallyCommented = theLine.info?.commentRanges.contains{ $0.contains(lineLocation)
                                      || $0.contains(lineLocation + range.length) }
            if partiallyCommented == true {

              if isCommented(line: firstLine) {
                newRange = uncomment(line: firstLine, with: range)
              } else {
                newRange = comment(line: firstLine, with: range)
              }

            } else {
              newRange = commentBracket(range: range)
            }

          }

        } else {

          // Case 3 of the specification
          // NB: It is crucial to process lines in reverse order as any text change invalidates ranges in the line map
          //     after the change.
          guard let lastLine = lines.last
          else {
            newSelected.append(range)
            continue
          }
          if isCommented(line: firstLine) && isCommented(line: lastLine) {
            for line in lines.reversed() { newRange = uncomment(line: line, with: newRange) }
          } else {
            for line in lines.reversed() { newRange = comment(line: line, with: newRange) }
          }

        }
        newSelected.append(newRange)
      }
#if os(macOS)
      if !newSelected.isEmpty { selectedRanges = newSelected.map{ NSValue(range: $0) } }
#elseif os(iOS) || os(visionOS)
      if let selection = newSelected.first { selectedRange = selection }
#endif
    }
  }
}
