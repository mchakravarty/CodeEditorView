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

  /// This is a temporary kludge to fix the height of the extra line fragment in case the size of the font used in the
  /// rest of the layout fragment varies from the standard font size. In TextKit 2, it is far from clear how to
  /// indicate the metrics to be used in a nicer manner. (Just setting the default font of the text view doesn't seem
  /// to work.)
  ///
  /// The solution here only works if there is at least one other line fragment (but that's always the case if the
  /// displayed string is now empty) and we use them same font height everywhere (which is the case for a code view).
  /// We simply use height of another line fragement for that of the extra line fragment and adjust the overall frame
  /// accordingly.
  ///
  var layoutFragmentFrameAdjustedKludge: CGRect {
    var frame = layoutFragmentFrame

    // If this layout fragment's last line fragment is for an empty string, then it is an extra line fragment and we
    // deduct its height from the layout fragment's height.
    if let firstTextLineFragment = textLineFragments.first,
       let lastTextLineFragment = textLineFragments.last,
       lastTextLineFragment.characterRange.length == 0
    {
      frame.size.height -= lastTextLineFragment.typographicBounds.height
      frame.size.height += firstTextLineFragment.typographicBounds.height
    }
    return frame
  }

  /// Yield the frame of the layout fragment's extra line fragment if present (which is the case if this the last
  /// line fragment and it is terminated by a newline character).
  ///
  var layoutFragmentFrameExtraLineFragment: CGRect? {

    // If this layout fragment's last line fragment is for an empty string, then it is an extra line fragment and 
    // return its bounds.
    if let lastTextLineFragment = textLineFragments.last, lastTextLineFragment.characterRange.length == 0 {
      let height = lastTextLineFragment.typographicBounds.height
      return CGRect(x: layoutFragmentFrame.minX,
                    y: layoutFragmentFrame.maxY - height,
                    width: layoutFragmentFrame.width,
                    height: height)
    } else {
      return nil
    }
  }
}

extension NSTextLayoutManager {
  
  /// Yield the height of the entire set of text fragments covering the given text range.
  ///
  /// - Parameter textRange: The text range for which we want to compute the height of the text fragments.
  /// - Returns: The height of the text fragments.
  ///
  /// If there are gaps, they are included. If the range reaches until the end of the text and there is extra line
  /// fragment, then it is included, too.
  ///
  func textLayoutFragmentExtent(for textRange: NSTextRange) -> (y: CGFloat, height: CGFloat)? {
    let location = textRange.location

    if location.compare(documentRange.endLocation) == .orderedSame { // Start of range == end of the document

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
          startFrame    = startFragment?.layoutFragmentFrame,
          endFragment   = if let endLocation { textLayoutFragment(for: endLocation) }
                          else { nil as NSTextLayoutFragment? },
          endFrame      = endFragment?.layoutFragmentFrameAdjustedKludge

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
    // FIXME: This doesn't work if the options include `.reverse`.
    enumerateTextLayoutFragments(from: textRange.location, options: options) { textLayoutFragment in
      textLayoutFragment.rangeInElement.location.compare(textRange.endLocation) == .orderedAscending
      && block(textLayoutFragment)
    }
  }
  
  /// Compute the smallest rect that encompasses all text layout fragments that (partly) lie in the given range.
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
  
  /// Determine the bounding rect of the first text segment of a given text range.
  ///
  /// - Parameter textRange: The text range for which we want to determine the first segment.
  /// - Returns: The bounding rect of the first text segment if any.
  ///
  func boundingRectOfFirstTextSegment(for textRange: NSTextRange) -> CGRect? {
    var result: CGRect?
    enumerateTextSegments(in: textRange, type: .standard, options: .rangeNotRequired) { (_, rect, _, _) in
      result = rect
      return false
    }
    return result
  }
  
  /// Enumerates the rendering attributes within a given range.
  ///
  /// - Parameters:
  ///   - textRange: The text range whose rendering attributes are to be enumerated.
  ///   - reverse: Whether to enumerate in reverse; i.e., right-to-left.
  ///   - block: A closure invoked for each attribute run within the range.
  ///
  func enumerateRenderingAttributes(in textRange: NSTextRange,
                                    reverse: Bool,
                                    using block: (NSTextLayoutManager, [NSAttributedString.Key : Any], NSTextRange) -> Void)
  {
    if !reverse {

      enumerateRenderingAttributes(from: textRange.location, reverse: false) { textLayoutManager, attributes, attributeRange in

        if let clippedRange = attributeRange.intersection(textRange) {
          block(textLayoutManager, attributes, clippedRange)
        }
        return attributeRange.endLocation.compare(textRange.endLocation) == .orderedAscending
      }

    } else {

      enumerateRenderingAttributes(from: textRange.endLocation, reverse: true) { textLayoutManager, attributes, attributeRange in

        if let clippedRange = attributeRange.intersection(textRange) {
          block(textLayoutManager, attributes, clippedRange)
        }
        return attributeRange.location.compare(textRange.location) == .orderedDescending
      }

    }
  }

  /// A set of string attributes together with a text range to which theu apply.
  ///
  typealias AttributeRun = (attributes: [NSAttributedString.Key : Any], textRange: NSTextRange)

  /// Collect all rendering attributes and their character ranges within a given text range.
  ///
  /// - Parameter textRange: The text range in which we want to collect rendering attributes.
  /// - Returns: An array of pairs and associated range for all rendering attributes within the given text range.
  ///
  func renderingAttributes(in textRange: NSTextRange) -> [AttributeRun] {

    var attributes: [(attributes: [NSAttributedString.Key : Any], textRange: NSTextRange)] = []
    enumerateRenderingAttributes(in: textRange, reverse: false) { attributes.append((attributes: $1, textRange: $2)) }
    return attributes
  }
}
