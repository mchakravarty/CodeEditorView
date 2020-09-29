//
//  GutterView.swift
//  
//
//  Created by Manuel M T Chakravarty on 23/09/2020.
//

#if os(iOS)

import UIKit


class GutterView: UIView {

  /// The text view (UIKit or AppKit) that this gutter belongs to.
  ///
  let textView: TextView

  var optLayoutManager: NSLayoutManager? { textView.optLayoutManager }
  var optTextContainer: NSTextContainer? { textView.optTextContainer }
  var optTextStorage:   NSTextStorage?   { textView.optTextStorage }

  let backgroundColour = UIColor.lightGray  // TODO: eventually use the same bg colour as the rest of the text view

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: TextView) {
    self.textView = textView
    super.init(frame: frame)
    let
      gutterExclusionPath = UIBezierPath(rect: CGRect(origin: frame.origin,
                                                      size: CGSize(width: frame.width,
                                                                   height: CGFloat.greatestFiniteMagnitude)))
    optTextContainer?.exclusionPaths = [gutterExclusionPath]
  }

  required init(coder: NSCoder) {
    fatalError("CodeEditorView.GutterView.init(coder:) not implemented")
  }

  override func draw(_ rect: CGRect) {
    guard let layoutManager = optLayoutManager,
          let textContainer = optTextContainer
    else { return }

    // TODO: we leave the background drawing to the text view
    backgroundColour.setFill()
    UIBezierPath(rect: rect).fill()

    // All visible glyphs and all visible characters
    let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: rect, in: textContainer),
        charRange  = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    /// TODO: now we need a line map to figure out on which line a particular character (given by its index) is located
  }

}

#elseif os(macOS)

import AppKit


class GutterView: NSView {

}

#endif

/* Good way to enumerate all the visible line numbers (what did we do in HfM?)
 [self enumerateLineFragmentsForGlyphRange:glyphsToShow
                                usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *textContainer, NSRange glyphRange, BOOL *stop) {
                                    NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
                                    NSRange paraRange = [self.textStorage.string paragraphRangeForRange:charRange];

                                    //   Only draw line numbers for the paragraph's first line fragment.  Subsiquent fragments are wrapped portions of the paragraph and don't
                                    //   get the line number.
                                    if (charRange.location == paraRange.location) {
                                        gutterRect = CGRectOffset(CGRectMake(0, rect.origin.y, 40.0, rect.size.height), origin.x, origin.y);
                                        paraNumber = [self _paraNumberForRange:charRange];
                                        NSString* ln = [NSString stringWithFormat:@"%ld", (unsigned long) paraNumber + 1];
                                        CGSize size = [ln sizeWithAttributes:atts];

                                        [ln drawInRect:CGRectOffset(gutterRect, CGRectGetWidth(gutterRect) - 4 - size.width, (CGRectGetHeight(gutterRect) - size.height) / 2.0)
                                        withAttributes:atts];
                                    }
                                }];

 //  Deal with the special case of an empty last line where enumerateLineFragmentsForGlyphRange has no line
 //  fragments to draw.
 if (NSMaxRange(glyphsToShow) > self.numberOfGlyphs) {
     NSString* ln = [NSString stringWithFormat:@"%ld", (unsigned long) paraNumber + 2];
     CGSize size = [ln sizeWithAttributes:atts];

     gutterRect = CGRectOffset(gutterRect, 0.0, CGRectGetHeight(gutterRect));
     [ln drawInRect:CGRectOffset(gutterRect, CGRectGetWidth(gutterRect) - 4 - size.width, (CGRectGetHeight(gutterRect) - size.height) / 2.0)
     withAttributes:atts];
 }

 */

