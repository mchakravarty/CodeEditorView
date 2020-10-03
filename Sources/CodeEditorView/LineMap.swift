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
}

