//
//  LayoutManagerExtras.swift
//  
//
//  Created by Manuel M T Chakravarty on 22/02/2023.
//

import SwiftUI


// MARK: Layout manager extensions

extension NSLayoutManager {

  /// Enumerate the fragment rectangles covering the characters located on the line with the given character index.
  ///
  /// - Parameters:
  ///   - charIndex: The character index determining the line whose rectangles we want to enumerate.
  ///   - block: Block that gets invoked once for every fragement rectangles on that line.
  ///
  func enumerateFragmentRects(forLineContaining charIndex: Int, using block: @escaping (CGRect) -> Void) {
    guard let text = textStorage?.string as NSString? else { return }

    let currentLineCharRange = text.lineRange(for: NSRange(location: charIndex, length: 0))

    if currentLineCharRange.length > 0 {  // all, but the last line (if it is an empty line)

      let currentLineGlyphRange = glyphRange(forCharacterRange: currentLineCharRange, actualCharacterRange: nil)
      enumerateLineFragments(forGlyphRange: currentLineGlyphRange){ (rect, _, _, _, _) in block(rect) }

    } else {                              // the last line if it is an empty line

      block(extraLineFragmentRect)

    }
  }

  /// Determines whether there are unlaid characters in this layout manager.
  /// 
  var hasUnlaidCharacters: Bool {
    firstUnlaidCharacterIndex() < (textStorage?.length ?? 0)
  }
}


