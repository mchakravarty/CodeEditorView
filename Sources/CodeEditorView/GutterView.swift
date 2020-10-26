//
//  GutterView.swift
//  
//
//  Created by Manuel M T Chakravarty on 23/09/2020.
//

import os


private let logger = Logger(subsystem: "org.justtesting.CodeEditor", category: "GutterView")

#if os(iOS)


// MARK: -
// MARK: UIKit version

import UIKit

class GutterView<TextViewType: TextView>: UIView where TextViewType.Color == UIColor, TextViewType.Font == UIFont {

  /// The text view (UIKit or AppKit) that this gutter belongs to.
  ///
  let textView: TextViewType

  var optLayoutManager: NSLayoutManager? { textView.optLayoutManager }
  var optTextContainer: NSTextContainer? { textView.optTextContainer }
  var optTextStorage:   NSTextStorage?   { textView.optTextStorage }
  var optLineMap:       LineMap<Void>?   { textView.optLineMap }

  let backgroundColour = UIColor.lightGray  // TODO: eventually use the same bg colour as the rest of the text view

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: TextViewType) {
    self.textView = textView
    super.init(frame: frame)
    let
      gutterExclusionPath = UIBezierPath(rect: CGRect(origin: frame.origin,
                                                      size: CGSize(width: frame.width,
                                                                   height: CGFloat.greatestFiniteMagnitude)))
    optTextContainer?.exclusionPaths = [gutterExclusionPath]
    contentMode = .redraw
  }

  required init(coder: NSCoder) {
    fatalError("CodeEditorView.GutterView.init(coder:) not implemented")
  }

  override func draw(_ rect: CGRect) {
    guard let layoutManager = optLayoutManager,
          let textContainer = optTextContainer,
          let lineMap       = optLineMap
    else { return }

    // Inherit background colour and line number font size from the text view.
    textView.textBackgroundColor?.setFill()
    UIBezierPath(rect: rect).fill()
    let fontSize = textView.textFont?.pointSize ?? UIFont.systemFontSize,
        desc     = UIFont.systemFont(ofSize: fontSize).fontDescriptor.addingAttributes(
                     [ UIFontDescriptor.AttributeName.featureSettings:
                         [
                           [
                             UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                             UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector,
                           ],
                           [
                             UIFontDescriptor.FeatureKey.featureIdentifier: kStylisticAlternativesType,
                             UIFontDescriptor.FeatureKey.typeIdentifier: kStylisticAltOneOnSelector,  // alt 6 and 9
                           ],
                           [
                             UIFontDescriptor.FeatureKey.featureIdentifier: kStylisticAlternativesType,
                             UIFontDescriptor.FeatureKey.typeIdentifier: kStylisticAltTwoOnSelector,  // alt 4
                           ]
                         ]
                     ]
                   ),
        font     = UIFont(descriptor: desc, size: 0)

    // All visible glyphs and all visible characters that are in the text area to the right of the gutter view
    let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: textRectFrom(gutterRect: rect),
                                              in: textContainer),
        charRange  = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil),
        lineRange  = lineMap.linesContaining(range: charRange)

    // Text attributes for the line numbers
    let lineNumberStyle = NSMutableParagraphStyle()
    lineNumberStyle.alignment = .right
    lineNumberStyle.tailIndent = -fontSize / 11
    let textAttributes = [NSAttributedString.Key.font: font,
                          .foregroundColor: UIColor.secondaryLabel,
                          .paragraphStyle: lineNumberStyle,
                          .kern: NSNumber(value: Float(-fontSize / 11))]

    for line in lineRange {
      logger.log("Line: \(line)")

      let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineMap.lines[line].range,
                                                    actualCharacterRange: nil),
          lineGlyphRect  = layoutManager.boundingRect(forGlyphRange: lineGlyphRange, in: textContainer)

      ("\(line)" as NSString).draw(in: gutterRectForLineNumbersFrom(textRect: lineGlyphRect),
                                   withAttributes: textAttributes)
    }
  }
}

#elseif os(macOS)


// MARK: -
// MARK: AppKit version

import AppKit


class GutterView: NSView {

}

#endif


// MARK: -
// MARK: Shared code

extension GutterView {

  /// Compute the full width rectangle in the gutter from a text container rectangle, such that they both have the same
  /// vertical extension.
  ///
  private func gutterRectFrom(textRect: CGRect) -> CGRect {
    return CGRect(origin: CGPoint(x: 0, y: textRect.origin.y + textView.textContainerOrigin.y),
                  size: CGSize(width: frame.size.width, height: textRect.size.height))
  }

  /// Compute the line number glyph rectangle in the gutter from a text container rectangle, such that they both have
  /// the same vertical extension.
  ///
  private func gutterRectForLineNumbersFrom(textRect: CGRect) -> CGRect {
    let gutterRect = gutterRectFrom(textRect: textRect)
    return CGRect(x: gutterRect.origin.x + gutterRect.size.width * 2/7,
                  y: gutterRect.origin.y,
                  width: gutterRect.size.width * 4/7,
                  height: gutterRect.size.height)
  }

  /// Compute the full width rectangle in the text container from a gutter rectangle, such that they both have the same
  /// vertical extension.
  ///
  private func textRectFrom(gutterRect: CGRect) -> CGRect {
    return CGRect(origin: CGPoint(x: frame.size.width, y: gutterRect.origin.y - textView.textContainerOrigin.y),
                  size: CGSize(width: optTextContainer?.size.width ?? 0, height: gutterRect.size.height))
  }
}
