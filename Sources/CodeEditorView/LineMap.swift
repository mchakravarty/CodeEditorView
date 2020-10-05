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
  init(string: String) {
    let nsString = string as NSString

    // Enumerate over all lines in `string`, adding them to the `map`.
    //
    var currentIndex = 0
    while currentIndex < nsString.length {

      let currentRange = nsString.lineRange(for: NSRange(location: currentIndex, length: 0))
      lines.append((range: currentRange, info: nil))
      currentIndex = NSMaxRange(currentRange)

    }

    // Check if there is an empty last line (due to a linebreak being at the end of the text), and if so, add that
    // extra empty line to the map.
    //
    let lastRange = nsString.lineRange(for: NSRange(location: nsString.length, length: 0))
    if lastRange.length == 0 {
      lines.append((range: lastRange, info: nil))
    }
  }

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
  /// This functions asymptotic complexity is logarithmic in the number of lines contained in the line map.
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

  /// MARK: -
  /// MARK: Editing

  /// Update line map given the specified editing activity of the underlying string.
  ///
  /// - Parameters:
  ///   - string: The string after editing.
  ///   - editedRange: The character range that was affected by editing (after editing).
  ///   - delta: The length increase of the edited string (negative if it got shorter).
  ///
  mutating func updateAfterEditing(string: String, range editedRange: NSRange, changeInLength delta: Int) {

  }

}

