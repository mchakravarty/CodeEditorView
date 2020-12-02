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


private typealias BezierPath     = UIBezierPath
private typealias Font           = UIFont
private typealias FontDescriptor = UIFontDescriptor

private let fontDescriptorFeatureIdentifier = FontDescriptor.FeatureKey.featureIdentifier
private let fontDescriptorTypeIdentifier    = FontDescriptor.FeatureKey.typeIdentifier

private let lineNumberColour = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

class GutterView: UIView {

  /// The text view that this gutter belongs to.
  ///
  let textView: UITextView

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: UITextView) {
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
}

#elseif os(macOS)


// MARK: -
// MARK: AppKit version

import AppKit


private typealias BezierPath     = NSBezierPath
private typealias Font           = NSFont
private typealias FontDescriptor = NSFontDescriptor

private let fontDescriptorFeatureIdentifier = FontDescriptor.FeatureKey.typeIdentifier
private let fontDescriptorTypeIdentifier    = FontDescriptor.FeatureKey.selectorIdentifier

private let lineNumberColour = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

class GutterView: NSView {

  /// The text view that this gutter belongs to.
  ///
  let textView: NSTextView

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: NSTextView) {
    self.textView = textView
    super.init(frame: frame)
    let
      gutterExclusionPath = NSBezierPath(rect: CGRect(origin: frame.origin,
                                                      size: CGSize(width: frame.width,
                                                                   height: CGFloat.greatestFiniteMagnitude)))
    optTextContainer?.exclusionPaths = [gutterExclusionPath]
    // NB: If were decide to use layer backing, we need to set the `layerContentsRedrawPolicy` to redraw on resizing
  }

  required init(coder: NSCoder) {
    fatalError("CodeEditorView.GutterView.init(coder:) not implemented")
  }
}

#endif


// MARK: -
// MARK: Shared code


extension GutterView {

  var optLayoutManager: NSLayoutManager?   { textView.optLayoutManager }
  var optTextContainer: NSTextContainer?   { textView.optTextContainer }
  var optTextStorage:   NSTextStorage?     { textView.optTextStorage }
  var optLineMap:       LineMap<LineInfo>? { textView.optLineMap }

  override func draw(_ rect: CGRect) {
    guard let layoutManager = optLayoutManager,
          let textContainer = optTextContainer,
          let lineMap       = optLineMap
    else { return }

    // Inherit background colour and line number font size from the text view.
    textView.textBackgroundColor?.setFill()
    BezierPath(rect: rect).fill()
    let fontSize = textView.textFont?.pointSize ?? Font.systemFontSize,
        desc     = Font.systemFont(ofSize: fontSize).fontDescriptor.addingAttributes(
                     [ FontDescriptor.AttributeName.featureSettings:
                         [
                           [
                             fontDescriptorFeatureIdentifier: kNumberSpacingType,
                             fontDescriptorTypeIdentifier: kMonospacedNumbersSelector,
                           ],
                           [
                             fontDescriptorFeatureIdentifier: kStylisticAlternativesType,
                             fontDescriptorTypeIdentifier: kStylisticAltOneOnSelector,  // alt 6 and 9
                           ],
                           [
                             fontDescriptorFeatureIdentifier: kStylisticAlternativesType,
                             fontDescriptorTypeIdentifier: kStylisticAltTwoOnSelector,  // alt 4
                           ]
                         ]
                     ]
                   )
    #if os(iOS)
    let font = Font(descriptor: desc, size: 0)
    #elseif os(macOS)
    let font = Font(descriptor: desc, size: 0) ?? Font.systemFont(ofSize: 0)
    #endif


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
                          .foregroundColor: lineNumberColour,
                          .paragraphStyle: lineNumberStyle,
                          .kern: NSNumber(value: Float(-fontSize / 11))]

    for line in lineRange {

      let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineMap.lines[line].range,
                                                    actualCharacterRange: nil),
          lineGlyphRect  = layoutManager.boundingRect(forGlyphRange: lineGlyphRange, in: textContainer)

      ("\(line)" as NSString).draw(in: gutterRectForLineNumbersFrom(textRect: lineGlyphRect),
                                   withAttributes: textAttributes)
    }
  }
}

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
