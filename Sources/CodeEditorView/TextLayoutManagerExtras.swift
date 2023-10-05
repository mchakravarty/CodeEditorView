//
//  TextLayoutManagerExtras.swift
//
//
//  Created by Manuel M T Chakravarty on 01/10/2023.
//

import SwiftUI


extension NSTextLayoutFragment {

  /// Yield the layout fragment's frame, but without the height of an extra line fragment if present.
  ///
  var layoutFragmentFrameWithoutExtraLineFragment: CGRect {
    var frame = layoutFragmentFrame

    // If this layout fragment's last line fragment is for an empty string, then it is an extra line fragment and we
    // deduct its height from the layout fragment's height.
    if let lastTextLineFragment = textLineFragments.last, lastTextLineFragment.characterRange.length == 0 {
      frame.size.height -= lastTextLineFragment.typographicBounds.height
    }
    return frame
  }
}

extension NSTextLayoutManager {
  
  /// Yield the height of the entire set of text fragments covering the given text range.
  ///
  /// - Parameter textRange: The text range for which we want to compute the height of the text fragments.
  /// - Returns: The height of the text fragments.
  ///
  /// If there are gaps, they are included. At the end of the text, if there is an extra line fragment, we return its
  /// height, but we exclude the extra line fragment from the preceeding line's height. (It is in the same text layout
  /// fragment.)
  ///
  func textLayoutFragmentExtent(for textRange: NSTextRange) -> (y: CGFloat, height: CGFloat)? {
    let location = textRange.location

    if location.compare(documentRange.endLocation) == .orderedSame { // End of the document

      if let lastLocation           = textContentManager?.location(textRange.endLocation, offsetBy: -1),
         let lastTextLayoutFragment = textLayoutFragment(for: lastLocation),
         let lastTextLineFragment   = lastTextLayoutFragment.textLineFragments.last,
         lastTextLineFragment.characterRange.length == 0
      {         // trailing newline at the end of the document

        // Extra line fragement
        let typographicBounds = lastTextLineFragment.typographicBounds
        return (y: lastTextLayoutFragment.layoutFragmentFrame.minY + typographicBounds.minY,
                height: typographicBounds.height)

      } else {  // no trailing newline at the end of the document

        if let endLocation = textContentManager?.location(textRange.endLocation, offsetBy: -1) ,
           let endFrame    = textLayoutFragment(for: endLocation)?.layoutFragmentFrame
        {

          return (y: endFrame.minY, height: endFrame.height)

        } else { return nil }

      }

    } else {

      let endLocation   = if textRange.isEmpty { nil as NSTextLocation? }
                          else { textContentManager?.location(textRange.endLocation, offsetBy: -1) },
          startFragment = textLayoutFragment(for: location),
          startFrame    = startFragment?.layoutFragmentFrameWithoutExtraLineFragment,
          endFragment   = if let endLocation { textLayoutFragment(for: endLocation) }
                          else { nil as NSTextLayoutFragment? },
          endFrame      = endFragment?.layoutFragmentFrameWithoutExtraLineFragment

      switch (startFrame, endFrame) {
      case (nil, nil):                   return nil
      case (.some(let startFrame), nil): return (y: startFrame.minY, height: startFrame.height)
      case (nil, .some(let endFrame)):   return (y: endFrame.minY, height: endFrame.height)

      case (.some(let startFrame), .some(let endFrame)):
        if startFrame.minY < endFrame.minY {
          return (y: startFrame.minY, height: endFrame.maxY - startFrame.minY)
        } else {
          return (y: endFrame.minY, height: startFrame.maxY - endFrame.minY)
        }
      }
    }
  }

  /// Enumerate all the text layout fragments that lie (partly) in the given range.
  ///
  /// - Parameters:
  ///   - range: The range for which we want to enumerate the text layout fragments.
  ///   - options: Enumeration options.
  ///   - block: The block to invoke on each eumerated text layout fragment.
  /// - Returns: See `NSTextLayoutFragment.enumerateTextLayoutFragments(from:options:using:)`.
  ///
  @discardableResult
  func enumerateTextLayoutFragments(in textRange: NSTextRange,
                                    options: NSTextLayoutFragment.EnumerationOptions = [],
                                    using block: (NSTextLayoutFragment) -> Bool)
  -> NSTextLocation?
  {
    enumerateTextLayoutFragments(from: textRange.location, options: options) { textLayoutFragment in
      textLayoutFragment.rangeInElement.location.compare(textRange.endLocation) == .orderedAscending
      && block(textLayoutFragment)
    }
  }
  
  /// Compute smallest rect that encompasses all text layout fragments that (partly) lie in the given range.
  ///
  /// - Parameter textRange: The range for which we want to compute the bounding box.
  /// - Returns: The bounding box.
  ///
  func textLayoutFragmentBoundingRect(for textRange: NSTextRange) -> CGRect {

    var boundingBox: CGRect = .null
    enumerateTextLayoutFragments(in: textRange, options: [.ensuresExtraLineFragment]) { textLayoutFragment in
      boundingBox = boundingBox.union(textLayoutFragment.layoutFragmentFrame)
      return true
    }
    return boundingBox
  }
}
