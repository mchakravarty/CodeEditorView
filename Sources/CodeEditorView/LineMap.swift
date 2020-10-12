//
//  LineMap.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//

import Foundation


/// Keeps track of the character ranges and parametric `LineInfo` for all lines in a string.
///
struct LineMap<LineInfo> {

  /// The character range of the line in the underlying string together with additional information if available.
  ///
  typealias OneLine = (range: NSRange, info: LineInfo?)

  /// One entry per line of the underlying string, where `lineMap[0]` is always `NSRange(location: 0, length: 0)` with
  /// no extra info.
  ///
  var lines: [OneLine] = [(range: NSRange(location: 0, length: 0), info: nil)]

  /// MARK: -
  /// MARK: Initialisation

  /// Direct initialisation for testing.
  ///
  init(lines: [OneLine]) { self.lines = lines }

  /// Initialise a line map with the string to be mapped.
  ///
  init(string: String) { lines.append(contentsOf: linesOf(string: string)) }

  /// MARK: -
  /// MARK: Queries

  /// Safe lookup of the information pertaining to a given line.
  ///
  /// - Parameter line: The line to look up.
  /// - Returns: The description of the given line if it is within the valid range of the line map.
  ///
  func lookup(line: Int) -> OneLine? { return line < lines.count ? lines[line] : nil }

  /// Determine the line that contains the characters at the given string index. (Safe to be called with an out of
  /// bounds index.)
  ///
  /// - Parameter index: The string index of the characters whose line we want to determine.
  /// - Returns: The line containing the indexed character if the index is within the bounds of the string.
  ///
  /// - Complexity: This functions asymptotic complexity is logarithmic in the number of lines contained in the line map.
  ///
  func lineContaining(index: Int) -> Int? {
    var lineRange = 1..<lines.count

    while lineRange.count > 1 {

      let middle = lineRange.startIndex + lineRange.count / 2
      if index < lines[middle].range.location {

        lineRange = lineRange.startIndex..<middle

      } else {

        lineRange = middle..<lineRange.endIndex

      }
    }
    if lineRange.count == 0 || !lines[lineRange.startIndex].range.contains(index) {

      return nil

    } else {

      return lineRange.startIndex

    }
  }

  /// Determine the line that contains the cursor position specified by the given string index. (Safe to be called with
  /// an out of bounds index.)
  ///
  /// Corresponds to `lineContaining(index:)`, but also handles the index just after the last valid string index — i.e.,
  /// the end-of-string insertion point.
  ///
  /// - Parameter index: The string index of the cursor position whose line we want to determine.
  /// - Returns: The line containing the given cursor poisition if the index is within the bounds of the string or
  ///            just beyond.
  ///
  /// - Complexity: This functions asymptotic complexity is logarithmic in the number of lines contained in the line
  ///               map.
  ///
  func lineOf(index: Int) -> Int? {
    if let lastLine = lines.last, NSMaxRange(lastLine.range) == index { return lines.count - 1 }
    else { return lineContaining(index: index) }
  }

  /// Given a character range, return the smallest line range that includes the characters plus maybe a trailing empty
  /// line. Deal with out of bounds conditions by clipping to the front and end of the line range, respectively.
  ///
  /// - Parameter range: The character range for which we want to know the line range.
  /// - Returns: The smallest range of lines that includes all characters in the given character range.
  ///
  /// There are two special cases:
  /// - If the resulting line range is being followed by a trailing empty line, that trailing empty line is also
  ///   included in the result.
  /// - If the character range is of length zero, we return the line of the start location. We do that also if the start
  ///   location is just behind the last character of the text.
  ///
  func linesContaining(range: NSRange) -> Range<Int> {
    let
      start       = range.location < 0 ? 0 : range.location,
      end         = range.length <= 0 ? start : NSMaxRange(range) - 1,
      startLine   = lineOf(index: start),
      endLine     = lineContaining(index: end),
      lastLine    = lines.count - 1,
      realEndLine : Int?

    if let endLine = endLine,
       endLine + 1 == lastLine,                                 // 'endLine' is right before the 'lastLine'
       lines[lastLine].range.length == 0                        // 'lastLine' is an empty line
    {

      realEndLine = lastLine                                    // extend 'endLine' to 'lastLine'

    } else { realEndLine = endLine }

    if let startLine = startLine {

      if range.length < 0 { return startLine..<startLine } else { return Range<Int>(startLine...(realEndLine ?? lastLine)) }

    } else {

      if range.location < 0 { return 0..<0 } else { return lastLine..<lastLine }

    }
  }

  /// MARK: -
  /// MARK: Editing

  /// Update line map given the specified editing activity of the underlying string.
  ///
  /// - Parameters:
  ///   - string: The string after editing.
  ///   - editedRange: The character range that was affected by editing (after editing).
  ///   - delta: The length increase of the edited string (negative if it got shorter).
  ///
  /// NB: The line after the `editedRange` will be updated (and info fields be invalidated) if the `editedRange` ends on
  ///     a newline.
  ///
  mutating func updateAfterEditing(string: String, range editedRange: NSRange, changeInLength delta: Int) {

    // If the given ranges are out of bounds of the given string, just recompute the complete line map.
    //
    let maxEditedRange = NSMaxRange(editedRange)
    if editedRange.location < 0 || editedRange.length < 0 || editedRange.length - delta < 0
        || maxEditedRange > string.count
        || maxEditedRange - delta > NSMaxRange(lines.last?.range ?? NSRange(location: 0, length: 0))
    {

      lines = [(range: NSRange(location: 0, length: 0), info: nil)] + linesOf(string: string)
      return

    }

    // Unless the edited range reaches to the end of the string, extend it by one character. This is crucial as, if the
    // edited range ends on a newline, this may insert a new line break, which means, we also need to update the line
    // *after* the new line break.
    let extendedEditedRange
      = maxEditedRange == string.count
      ? editedRange
      : NSRange(location: editedRange.location, length: editedRange.length + 1)

    let
      nsString       = string as NSString,
      oldLinesRange  = linesContaining(range: NSRange(location: extendedEditedRange.location,
                                                      length: extendedEditedRange.length - delta)),
      newLinesRange  = nsString.lineRange(for: extendedEditedRange),
      newLinesString = nsString.substring(with: newLinesRange),
      newLines       = linesOf(string: newLinesString).map{ shift(line: $0, by: newLinesRange.location) }

    // If the newly inserted text ends on a new line, we need to remove the empty trailing line in the new lines array
    // unless the range of those lines extends until the end of the string.
    let dropEmptyNewLine = newLines.last?.range.length == 0 && NSMaxRange(newLinesRange) < string.count,
        adjustedNewLines = dropEmptyNewLine ? newLines.dropLast() : newLines

    lines.replaceSubrange(oldLinesRange, with: adjustedNewLines)

    // All ranges after the edited range of lines need to be adjusted.
    //
    for i in oldLinesRange.startIndex.advanced(by: adjustedNewLines.count) ..< lines.count {
      lines[i] = shift(line: lines[i], by: delta)
    }
  }

  /// MARK: -
  /// MARK: Helpers

  /// Shift the range of `line` by `delta`.
  ///
  private func shift(line: OneLine, by delta: Int) -> OneLine {
    return (range: NSRange(location: line.range.location + delta, length: line.range.length), info: line.info)
  }

  /// Extract the corresponding array of line ranges out of the given string.
  ///
  private func linesOf(string: String) -> [OneLine] {
    let nsString = string as NSString

    var resultingLines: [OneLine] = []

    // Enumerate all lines in `nsString`, adding them to the `resultingLines`.
    //
    var currentIndex = 0
    while currentIndex < nsString.length {

      let currentRange = nsString.lineRange(for: NSRange(location: currentIndex, length: 0))
      resultingLines.append((range: currentRange, info: nil))
      currentIndex = NSMaxRange(currentRange)

    }

    // Check if there is an empty last line (due to a linebreak being at the end of the text), and if so, add that
    // extra empty line to the `resultingLines` as well.
    //
    let lastRange = nsString.lineRange(for: NSRange(location: nsString.length, length: 0))
    if lastRange.length == 0 {
      resultingLines.append((range: lastRange, info: nil))
    }

    return resultingLines
  }
}
