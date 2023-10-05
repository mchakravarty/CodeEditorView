//
//  GutterView.swift
//  
//
//  Created by Manuel M T Chakravarty on 23/09/2020.
//

import os

import Rearrange

import LanguageSupport


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "GutterView")

#if os(iOS)


// MARK: -
// MARK: UIKit version

import UIKit


private typealias FontDescriptor = UIFontDescriptor

private let fontDescriptorFeatureIdentifier = FontDescriptor.FeatureKey.type
private let fontDescriptorTypeIdentifier    = FontDescriptor.FeatureKey.selector

private let lineNumberColour = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

class GutterView: UIView {

  /// The text view that this gutter belongs to.
  ///
  let textView: UITextView

  /// The current code editor theme
  ///
  var theme: Theme

  /// Accessor for the associated text view's message views.
  ///
  let getMessageViews: () -> MessageViews

  /// Determines whether this gutter is for a main code view or for the minimap of a code view.
  ///
  let isMinimapGutter: Bool = false

  /// Dirty rectangle whose drawing has been delayed as the code layout wasn't finished yet.
  ///
  var pendingDrawRect: CGRect?

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: UITextView, theme: Theme, getMessageViews: @escaping () -> MessageViews) {
    self.textView        = textView
    self.theme           = theme
    self.getMessageViews = getMessageViews
    super.init(frame: frame)
    let gutterExclusionPath = UIBezierPath(rect: CGRect(origin: frame.origin,
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


private typealias FontDescriptor = NSFontDescriptor

private let fontDescriptorFeatureIdentifier = FontDescriptor.FeatureKey.typeIdentifier
private let fontDescriptorTypeIdentifier    = FontDescriptor.FeatureKey.selectorIdentifier

private let lineNumberColour = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

class GutterView: NSView {

  /// The text view that this gutter belongs to.
  ///
  let textView: NSTextView

  /// The current code editor theme
  ///
  var theme: Theme

  /// Accessor for the associated text view's message views.
  ///
  let getMessageViews: () -> MessageViews

  /// Determines whether this gutter is for a main code view or for the minimap of a code view.
  ///
  let isMinimapGutter: Bool

  /// Create and configure a gutter view for the given text view. This will also set the appropiate exclusion path for
  /// text container.
  ///
  init(frame: CGRect, textView: NSTextView, theme: Theme, getMessageViews: @escaping () -> MessageViews, isMinimapGutter: Bool) {
    self.textView        = textView
    self.theme           = theme
    self.getMessageViews = getMessageViews
    self.isMinimapGutter = isMinimapGutter
    super.init(frame: frame)
    // NB: If were decide to use layer backing, we need to set the `layerContentsRedrawPolicy` to redraw on resizing
  }

  required init(coder: NSCoder) {
    fatalError("CodeEditorView.GutterView.init(coder:) not implemented")
  }

  // Imitate the coordinate system of the associated text view.
  override var isFlipped: Bool { textView.isFlipped }
}

#endif


// MARK: -
// MARK: Shared code


extension GutterView {

  var optTextLayoutManager: NSTextLayoutManager?   { textView.optTextLayoutManager }
  var optTextContainer:     NSTextContainer?       { textView.optTextContainer }
  var optLineMap:           LineMap<LineInfo>?     { textView.optLineMap }

  // MARK: -
  // MARK: Gutter notifications

  /// Notifies the gutter view that a range of characters will be redrawn by the layout manager or that there are
  /// selection status changes; thus, the corresponding gutter area might require redrawing, too.
  ///
  /// - Parameters:
  ///   - charRange: The invalidated range of characters. It will be trimmed to be within the valid character range of
  ///     the underlying text storage.
  ///
  /// We invalidate the area corresponding to entire paragraphs. This makes a difference in the presence of line
  /// breaks.
  ///
  func invalidateGutter(for charRange: NSRange) {
    guard let textLayoutManager   = optTextLayoutManager,
          let textContentStorage  = textLayoutManager.textContentManager as? NSTextContentStorage,
          let viewPortRange       = textLayoutManager.textViewportLayoutController.viewportRange,
          let charRangeInViewPort = textContentStorage.range(for: viewPortRange).intersection(charRange),
          let string              = textContentStorage.textStorage?.string as NSString?
    else { return }


    // We call `paragraphRange(for:_)` safely by boxing `charRange` to the allowed range.
    let extendedCharRange = string.paragraphRange(for: charRangeInViewPort.clamped(to: string.length))

    if let textRange = textContentStorage.textRange(for: extendedCharRange) {

      if let (y: y, height: height) = textLayoutManager.textLayoutFragmentExtent(for: textRange), height > 0  {
        setNeedsDisplay(gutterRectFrom(y: y, height: height))
      }
    }
  }

  // MARK: -
  // MARK: Gutter drawing

  override func draw(_ rect: CGRect) {
    guard let textLayoutManager  = optTextLayoutManager,
          let textContentStorage = textView.textContentStorage,
          let lineMap            = optLineMap
    else { return }

    // We can't draw the gutter without having layout information for the viewport.
    let viewPortBounds = textLayoutManager.textViewportLayoutController.viewportBounds
    textLayoutManager.ensureLayout(for: viewPortBounds)

    // From macOS 14, the system doesn't automatically clip drawing to view bounds. Hence, we clip the draw rect here
    // explicitly. We also assume that the super view for floating gutters has `clipToBounds == true` to avoid drawing
    // outside of the containing scroll view bounds.
    let rect = rect.intersection(bounds).intersection(viewPortBounds)

    theme.backgroundColour.setFill()
    OSBezierPath(rect: rect).fill()

    let desc = OSFont.systemFont(ofSize: theme.fontSize).fontDescriptor.addingAttributes(
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
    let font = OSFont(descriptor: desc, size: 0)
    #elseif os(macOS)
    let font = OSFont(descriptor: desc, size: 0) ?? OSFont.systemFont(ofSize: 0)
    #endif

    let selectedLines = textView.selectedLines

    // Currently only supported on macOS as `UITextView` is less configurable
    #if os(macOS)

    // Highlight the current line in the gutter
    if let location               = textView.insertionPoint,
       let textLocation           = textContentStorage.textLocation(for: location),
       let (y: y, height: height) = textLayoutManager.textLayoutFragmentExtent(for: NSTextRange(location: textLocation))
    {

      theme.currentLineColour.setFill()
      
      let intersectionRect = rect.intersection(gutterRectFrom(y: y, height: height))
      if !intersectionRect.isEmpty { NSBezierPath(rect: intersectionRect).fill() }

    }

// FIXME: for TextKit 2
    /*
    // FIXME: Eventually, we want this in the minimap, too, but `messageView.value.lineFragementRect` is of course
    //        incorrect for the minimap, so we need a more general set up.
    if !isMinimapGutter {

      // Highlight lines with messages
      for messageView in getMessageViews() {

        let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: messageView.value.lineFragementRect,
                                                  in: textContainer),
            index      = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        // TODO: should be filter by char range
        //      if charRange.contains(index) {

        messageView.value.colour.withAlphaComponent(0.1).setFill()
        layoutManager.enumerateFragmentRects(forLineContaining: index){ fragmentRect in
          let intersectionRect = rect.intersection(self.gutterRectFrom(textRect: fragmentRect))
          if !intersectionRect.isEmpty { NSBezierPath(rect: intersectionRect).fill() }
        }

  //      }
      }
    }
     */

    #endif

    // Determine the character range whose line numbers need to be drawn by narrowing down the viewport range
    guard var textRange = textLayoutManager.textViewportLayoutController.viewportRange else { return }
    if let firstLineFragmentRange = textLayoutManager.lineFragmentRange(for: CGPoint(x: 1, y: rect.minY),
                                                                        inContainerAt: textRange.location),
       textRange.location.compare(firstLineFragmentRange.location) == .orderedAscending,
       let newTextRange = NSTextRange(location: firstLineFragmentRange.location, end: textRange.endLocation)
    {
      textRange = newTextRange
    }
    if let lastLineFragmentRange = textLayoutManager.lineFragmentRange(for: CGPoint(x: 1, y: rect.maxY),
                                                                       inContainerAt: textRange.endLocation),
       lastLineFragmentRange.endLocation.compare(textRange.endLocation) == .orderedAscending,
       let newTextRange = NSTextRange(location: textRange.location, end: lastLineFragmentRange.endLocation)
    {
      textRange = newTextRange
    }
    let characterRange = textContentStorage.range(for: textRange)

    // Draw line numbers unless this is a gutter for a minimap
    if !isMinimapGutter {

      let lineRange = lineMap.linesOf(range: characterRange)

      // Text attributes for the line numbers
      let lineNumberStyle = NSMutableParagraphStyle()
      lineNumberStyle.alignment = .right
      lineNumberStyle.tailIndent = -theme.fontSize / 11
      let textAttributesDefault  = [NSAttributedString.Key.font: font,
                                    .foregroundColor: lineNumberColour,
                                    .paragraphStyle: lineNumberStyle,
                                    .kern: NSNumber(value: Float(-theme.fontSize / 11))],
          textAttributesSelected = [NSAttributedString.Key.font: font,
                                    .foregroundColor: theme.textColour,
                                    .paragraphStyle: lineNumberStyle,
                                    .kern: NSNumber(value: Float(-theme.fontSize / 11))]

      // TODO: CodeEditor needs to be parameterised by message theme
      let theme = Message.defaultTheme

      for line in lineRange {  // NB: These are zero-based line numbers

        guard let lineStartLocation  = textContentStorage.textLocation(for: lineMap.lines[line].range.location),
              let textLayoutFragment = textLayoutManager.textLayoutFragment(for: lineStartLocation)
        else { continue }

        let gutterRect = gutterRectForLineNumbersFrom(textRect: textLayoutFragment.layoutFragmentFrameWithoutExtraLineFragment)

        var attributes = selectedLines.contains(line) ? textAttributesSelected : textAttributesDefault

        #if os(iOS)

        // Highlight line numbers as we don't have line background highlighting on iOS.
        if let messageBundle = lineMap.lines[line].info?.messages, let message = messagesByCategory(messageBundle.messages).first {
          let themeColour = theme(message.key).colour,
              colour      = selectedLines.contains(line) ? themeColour : themeColour.withAlphaComponent(0.5)
          attributes.updateValue(colour, forKey: .foregroundColor)
        }

        #endif

        ("\(line + 1)" as NSString).draw(in: gutterRect, withAttributes: attributes)
      }

      // If we are at the end, we also draw a line number for the extra line fragement if that exists
      if lineRange.endIndex == lineMap.lines.count,
         let endLocation        = textContentStorage.location(textRange.endLocation, offsetBy: -1),
         let textLayoutFragment = textLayoutManager.textLayoutFragment(for: endLocation)
      {

        let textRect = textLayoutFragment
          .layoutFragmentFrame.divided(atDistance: textLayoutFragment.layoutFragmentFrameWithoutExtraLineFragment.height,
                                       from: .minYEdge).remainder
        let gutterRect = gutterRectForLineNumbersFrom(textRect: textRect)

        let attributes = textView.insertionPoint == textContentStorage.textStorage?.length
                         ? textAttributesSelected
                         : textAttributesDefault
        ("\(lineMap.lines.count)" as NSString).draw(in: gutterRect, withAttributes: attributes)

      }
    }

  }
}

extension GutterView {

  /// Compute the full width rectangle in the gutter from its vertical extent.
  ///
  private func gutterRectFrom(y: CGFloat, height: CGFloat) -> CGRect {
    return CGRect(origin: CGPoint(x: 0, y: y + textView.textContainerOrigin.y),
                  size: CGSize(width: frame.size.width, height: height))
  }

  /// Compute the full width rectangle in the gutter from a text container rectangle, such that they both have the same
  /// vertical extension.
  ///
  @available(*, deprecated, renamed: "gutterRectFrom(y:height:)", message: "")
  private func gutterRectFrom(textRect: CGRect) -> CGRect {
    return CGRect(origin: CGPoint(x: 0, y: textRect.origin.y + textView.textContainerOrigin.y),
                  size: CGSize(width: frame.size.width, height: textRect.size.height))
  }

// FIXME: TextKit 2: remove
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
    let containerWidth = optTextContainer?.size.width ?? 0
    return CGRect(origin: CGPoint(x: frame.size.width, y: gutterRect.origin.y - textView.textContainerOrigin.y),
                  size: CGSize(width: containerWidth - frame.size.width, height: gutterRect.size.height))
  }
}
