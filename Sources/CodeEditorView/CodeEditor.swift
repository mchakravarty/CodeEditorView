//
//  CodeEditor.swift
//
//  Created by Manuel M T Chakravarty on 23/08/2020.
//
//  SwiftUI 'CodeEditor' view

import SwiftUI


#if os(iOS)

// MARK: -
// MARK: UIKit version

/// `UITextView` with a gutter
///
fileprivate class CodeView: UITextView {

  fileprivate var gutterView:          GutterView?
  fileprivate var codeViewDelegate:    CodeViewDelegate?
  fileprivate var codeStorageDelegate: CodeStorageDelegate?

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration) {

    // Use custom components that are gutter-aware and support code-specific editing actions and highlighting.
    let codeLayoutManager = CodeLayoutManager(),
        codeContainer     = CodeContainer(),
        codeStorage       = CodeStorage()
    codeStorage.addLayoutManager(codeLayoutManager)
    codeContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(codeContainer)

    super.init(frame: frame, textContainer: codeContainer)
    codeContainer.textView = self

    // Set basic display and input properties
    font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
    backgroundColor        = UIColor.systemBackground
    autocapitalizationType = .none
    autocorrectionType     = .no
    spellCheckingType      = .no
    smartQuotesType        = .no
    smartDashesType        = .no
    smartInsertDeleteType  = .no

    // Add the view delegate
    codeViewDelegate = CodeViewDelegate(codeView: self)
    delegate         = codeViewDelegate

    // Add a text storage delegate that maintains a line map
    self.codeStorageDelegate = CodeStorageDelegate(with: language)
    codeStorage.delegate     = self.codeStorageDelegate

    // Add a gutter view
    let gutterWidth = (font?.pointSize ?? UIFont.systemFontSize) * 3,
        gutterView  = GutterView(frame: CGRect(x: 0,
                                               y: 0,
                                               width: gutterWidth,
                                               height:  CGFloat.greatestFiniteMagnitude),
                                 textView: self)
    addSubview(gutterView)
    self.gutterView              = gutterView
    codeLayoutManager.gutterView = gutterView
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    gutterView?.frame.size.height = contentSize.height
  }
}

fileprivate class CodeViewDelegate: NSObject, UITextViewDelegate {

  // Hooks for events
  //
  var textDidChange:      ((UITextView) -> ())?
  var selectionDidChange: ((UITextView) -> ())?

  /// Caching the last set selected range.
  ///
  var oldSelectedRange: NSRange

  init(codeView: CodeView) {
    oldSelectedRange = codeView.selectedRange
  }

  // MARK: -
  // MARK: UITextViewDelegate protocol

  func textDidChange(_ textView: UITextView) { textDidChange?(textView) }

  func textViewDidChangeSelection(_ textView: UITextView) {
    guard let codeView = textView as? CodeView else { return }

    selectionDidChange?(textView)

    codeView.gutterView?.invalidateGutter(forCharRange: NSUnionRange(codeView.selectedRange, oldSelectedRange))
    oldSelectedRange = textView.selectedRange
  }
}

class CodeContainer: NSTextContainer {
  weak var textView: UITextView?
}

/// SwiftUI code editor based on TextKit
///
public struct CodeEditor: UIViewRepresentable {
  let language: LanguageConfiguration

  @Binding var text: String

  public init(text: Binding<String>, with language: LanguageConfiguration = noConfiguration) {
    self._text    = text
    self.language = language
  }

  public func makeUIView(context: Context) -> UITextView {
    let textView = CodeView(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                                      with: language)

    textView.text = text
    if let delegate = textView.delegate as? CodeViewDelegate {
      delegate.textDidChange      = context.coordinator.textDidChange
      delegate.selectionDidChange = selectionDidChange
    }
    return textView
  }

  public func updateUIView(_ textView: UITextView, context: Context) {
    if text != textView.text { textView.text = text }  // Hoping for the string comparison fast path...
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator {
    @Binding var text: String

    init(_ text: Binding<String>) {
      self._text = text
    }

    func textDidChange(_ textView: UITextView) {
      self.text = textView.text
    }
  }
}


#elseif os(macOS)

// MARK: -
// MARK: AppKit version

/// `NSTextView` with a gutter
///
fileprivate class CodeView: NSTextView {

  // Delegates
  fileprivate var codeViewDelegate:      CodeViewDelegate?
  fileprivate var codeStorageDelegate:   CodeStorageDelegate?

  // Subviews
  fileprivate var gutterView:         GutterView?
  fileprivate var minimapView:        NSTextView?
  fileprivate var minimapGutterView:  GutterView?
  fileprivate var minimapDividerView: NSBox?

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration) {

    // Use custom components that are gutter-aware and support code-specific editing actions and highlighting.
    let codeLayoutManager = CodeLayoutManager(),
        codeContainer     = CodeContainer(),
        codeStorage       = CodeStorage()
    codeStorage.addLayoutManager(codeLayoutManager)
    codeContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(codeContainer)

    super.init(frame: frame, textContainer: codeContainer)

    // Set basic display and input properties
    font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    backgroundColor                      = NSColor.textBackgroundColor
    insertionPointColor                  = NSColor.textColor
    isRichText                           = false
    isAutomaticQuoteSubstitutionEnabled  = false
    isAutomaticLinkDetectionEnabled      = false
    smartInsertDeleteEnabled             = false
    isContinuousSpellCheckingEnabled     = false
    isGrammarCheckingEnabled             = false
    isAutomaticDashSubstitutionEnabled   = false
    isAutomaticDataDetectionEnabled      = false
    isAutomaticSpellingCorrectionEnabled = false
    isAutomaticTextReplacementEnabled    = false

    // Line wrapping
    isHorizontallyResizable             = false
    isVerticallyResizable               = true
    textContainerInset                  = CGSize(width: 0, height: 0)
    textContainer?.widthTracksTextView  = false   // we need to be able to control the size (see `tile()`)
    textContainer?.heightTracksTextView = false
    textContainer?.lineBreakMode        = .byWordWrapping

    // FIXME: properties that ought to be configurable
    usesFindBar                   = true
    isIncrementalSearchingEnabled = true

    // Add the view delegate
    codeViewDelegate = CodeViewDelegate()
    delegate         = codeViewDelegate

    // Add a text storage delegate that maintains a line map
    codeStorageDelegate  = CodeStorageDelegate(with: language)
    codeStorage.delegate = codeStorageDelegate

    // Add a gutter view
    let gutterView = GutterView(frame: CGRect.zero, textView: self, isMinimapGutter: false)
    gutterView.autoresizingMask = .none
    addSubview(gutterView)
    self.gutterView              = gutterView
    codeLayoutManager.gutterView = gutterView

    // Add the minimap with its own gutter, but sharing the code storage with the code view
    //
    let minimapLayoutManager = MinimapLayoutManager(),
        minimapView          = NSTextView(),
        minimapGutterView    = GutterView(frame: CGRect.zero, textView: minimapView, isMinimapGutter: true),
        minimapDividerView   = NSBox()

    minimapDividerView.boxType = .separator
    addSubview(minimapDividerView)
    self.minimapDividerView = minimapDividerView

    minimapView.textContainer?.replaceLayoutManager(minimapLayoutManager)
    codeStorage.addLayoutManager(minimapLayoutManager)
    minimapView.autoresizingMask                    = .none
    minimapView.isEditable                          = false
    minimapView.isSelectable                        = false
    minimapView.isHorizontallyResizable             = false
    minimapView.isVerticallyResizable               = true
    minimapView.textContainerInset                  = CGSize(width: 0, height: 0)
    minimapView.textContainer?.widthTracksTextView  = true
    minimapView.textContainer?.heightTracksTextView = false
    minimapView.textContainer?.lineBreakMode        = .byWordWrapping
    addSubview(minimapView)
    self.minimapView = minimapView

    minimapView.addSubview(minimapGutterView)
    self.minimapGutterView = minimapGutterView

    minimapView.layoutManager?.typesetter = MinimapTypeSetter()

    tile()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()

    // Lay out the various subviews and text containers
    tile()

    // Redraw the visible part of the gutter
    gutterView?.setNeedsDisplay(documentVisibleRect)
  }

  override func setSelectedRanges(_ ranges: [NSValue],
                                  affinity: NSSelectionAffinity,
                                  stillSelecting stillSelectingFlag: Bool)
  {
    let oldSelectedRanges = selectedRanges
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)

    // NB: This needs to happen after calling `super`, as it depends on the correctly set new set of ranges.
    gutterView?.invalidateGutter(forCharRange: combinedRanges(ranges: oldSelectedRanges + ranges))
  }

  /// Position and size the gutter and minimap and set the text container sizes and exclusion paths.
  ///
  /// * The main text view contains three subviews: (1) the main gutter on its left side, (2) the minimap on its right
  ///   side, and (3) a divide overlayed over the text view just left of the minimap.
  /// * Both the main text view and the minimap text view (or rather their text container) uses an exclusion path to
  ///   keep text out of the gutter view. The main text view is sized to avoid overlap with the minimap even without an
  ///   exclusion path.
  /// * The main text view and the minimap text view need to be able to accomodate exactly the same number of
  ///   characters, so that line breaking procceds in the exact same way.
  ///
  /// NB: We don't use a ruler view for the gutter on macOS to be able to use the same setup on macOS and iOS.
  ///
  private func tile() {

    // Compute size of the main view gutter
    //
    let theFont                = font ?? NSFont.systemFont(ofSize: 0),
        fontSize               = theFont.pointSize,
        fontWidth              = theFont.maximumAdvancement.width,  // NB: we deal only with fixed width fonts
        gutterWithInCharacters = CGFloat(6),
        gutterWidth            = fontWidth * gutterWithInCharacters,
        gutterRect             = CGRect(origin: CGPoint.zero, size: CGSize(width: gutterWidth, height: frame.height)),
        gutterExclusionPath    = BezierPath(rect: gutterRect),
        lineFragmentPadding    = textContainer?.lineFragmentPadding ?? 6

    gutterView?.frame = gutterRect

    // Compute sizes of the minimap text view and gutter
    //
    let minimapFontWidth     = minimapFontSize(for: fontSize) / 2,
        minimapGutterWidth   = minimapFontWidth * gutterWithInCharacters,
        minimapGutterRect    = CGRect(origin: CGPoint.zero,
                                      size: CGSize(width: minimapGutterWidth, height: frame.height)),
        widthWithoutGutters  = frame.width - gutterWidth - minimapGutterWidth
                                           - lineFragmentPadding * 2 + minimapFontWidth * 2,
        numberOfCharacters   = codeWidthInCharacters(for: widthWithoutGutters , with: theFont),
        minimapWidth         = minimapGutterWidth + minimapFontWidth * 2 + numberOfCharacters * minimapFontWidth,
        codeViewWidth        = gutterWidth + lineFragmentPadding * 2 + ceil(numberOfCharacters * fontWidth),
        minimapX             = frame.width - minimapWidth,
        minimapRect          = CGRect(x: minimapX, y: 0, width: minimapWidth, height: frame.height),
        minimapExclusionPath = BezierPath(rect: minimapGutterRect),
        minimapDividerRect   = CGRect(x: minimapX - 1, y: 0, width: 1, height: frame.height)

    minimapDividerView?.frame = minimapDividerRect
    minimapView?.frame        = minimapRect
    minimapGutterView?.frame  = minimapGutterRect

    minSize = CGSize(width: 0, height: documentVisibleRect.height)
    maxSize = CGSize(width: codeViewWidth, height: CGFloat.greatestFiniteMagnitude)

    // Set the text container area of the main text view to reach up to the minimap
    textContainerInset            = NSSize(width: 0, height: 0)
    textContainer?.size           = NSSize(width: codeViewWidth, height: CGFloat.greatestFiniteMagnitude)
    textContainer?.exclusionPaths = [gutterExclusionPath]

    // Set the text container area of the minimap text view
    minimapView?.textContainer?.exclusionPaths      = [minimapExclusionPath]
    minimapView?.textContainer?.size                = CGSize(width: minimapWidth,
                                                             height: CGFloat.greatestFiniteMagnitude)
    minimapView?.textContainer?.lineFragmentPadding = minimapFontWidth
  }

  /// Sets the scrolling position of the minimap in dependence of the scroll position of the main code view.
  ///
  func adjustScrollPositionOfMinimap() {
    let codeViewHeight = frame.size.height,
        minimapHeight  = minimapView?.frame.size.height ?? 0,
        visibleHeight  = documentVisibleRect.size.height

    let scrollFactor: CGFloat
    if minimapHeight < visibleHeight { scrollFactor = 1 } else {

      scrollFactor   = 1 - (minimapHeight - visibleHeight) / (codeViewHeight - visibleHeight)

    }
    minimapView?.frame.origin.y = min(max(documentVisibleRect.origin.y * scrollFactor, 0),
                                      frame.size.height - (minimapView?.frame.size.height ?? 0))
  }
}

fileprivate class CodeViewDelegate: NSObject, NSTextViewDelegate {

  // Hooks for events
  //
  var textDidChange:      ((NSTextView) -> ())?
  var selectionDidChange: ((NSTextView) -> ())?


  // MARK: -
  // MARK: NSTextViewDelegate protocol

  func textDidChange(_ notification: Notification) {
    guard let textView = notification.object as? NSTextView else { return }

    textDidChange?(textView)
  }

  func textViewDidChangeSelection(_ notification: Notification) {
    guard let textView = notification.object as? NSTextView else { return }

    selectionDidChange?(textView)
  }
}

class CodeContainer: NSTextContainer {
}

/// SwiftUI code editor based on TextKit
///
public struct CodeEditor: NSViewRepresentable {
  let language: LanguageConfiguration

  @Binding var text: String

  public init(text: Binding<String>, with language: LanguageConfiguration = noConfiguration) {
    self._text    = text
    self.language = language
  }

  public func makeNSView(context: Context) -> NSScrollView {

    // Set up scroll view
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    scrollView.borderType          = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalRuler  = false
    scrollView.autoresizingMask    = [.width, .height]

    // Set up text view with gutter
    let textView = CodeView(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                                      with: language)
    textView.isVerticallyResizable   = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask        = .width

    // Embedd text view in scroll view
    scrollView.documentView = textView

    textView.string = text
    if let delegate = textView.delegate as? CodeViewDelegate {
      delegate.textDidChange      = context.coordinator.textDidChange
      delegate.selectionDidChange = selectionDidChange
    }

    // The minimap needs to be vertically positioned in dependence on the scroll position of the main code view.
    context.coordinator.liveScrollNotificationObserver
      = NotificationCenter.default.addObserver(forName: NSScrollView.didLiveScrollNotification,
                                               object: scrollView,
                                               queue: .main){ _ in textView.adjustScrollPositionOfMinimap() }

    return scrollView
  }

  public func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    if text != textView.string { textView.string = text }  // Hoping for the string comparison fast path...
  }

  public func makeCoordinator() -> Coordinator {

    return Coordinator($text)
  }

  public final class Coordinator {
    @Binding var text: String

    var liveScrollNotificationObserver: NSObjectProtocol?

    init(_ text: Binding<String>) {
      self._text = text
    }

    deinit {
      if let oberver = liveScrollNotificationObserver { NotificationCenter.default.removeObserver(oberver) }
    }

    func textDidChange(_ textView: NSTextView) {
      self.text = textView.string
    }
  }
}

/// Customised layout manager for the minimap.
///
class MinimapLayoutManager: NSLayoutManager {

  // In place of drawing the actual glyphs, we draw small rectangles in the glyph's foreground colour. We ignore the
  // actual glyph metrics and draw all glyphs as a fixed-sized rectangle whose height is determined by the "used
  // rectangle" and whose width is a fraction of the actual (monospaced) font of the glyph (rounded to full points).
  override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard let textStorage = self.textStorage else { return }

    // Compute the width of a single rectangle representing one character in the original text display.
    var width: CGFloat
    let charIndex = self.characterIndexForGlyph(at: glyphsToShow.location)
    if let font = textStorage.attribute(.font, at: charIndex, effectiveRange: nil) as? NSFont {

      width = minimapFontSize(for: font.pointSize) / 2

    } else { width = 1 }

    enumerateLineFragments(forGlyphRange: glyphsToShow){ (_rect, usedRect, _textContainer, glyphRange, _) in

      let origin = usedRect.origin
      for index in 0..<glyphRange.length {

        // We don't draw hiden glyphs (`.null`), control chracters, and "elastic" glyphs, where the latter serve as a
        // proxy for white space
        let property = self.propertyForGlyph(at: glyphRange.location + index)
        if property != .null && property != .controlCharacter && property != .elastic {

          // TODO: could try to optimise by using the `effectiveRange` of the attribute lookup to compute an entire glyph run to draw as one rectangle
          let charIndex = self.characterIndexForGlyph(at: glyphRange.location + index)
          if let colour = textStorage.attribute(.foregroundColor, at: charIndex, effectiveRange: nil) as? NSColor {
            colour.setFill()
          }
          NSBezierPath(rect: CGRect(x: origin.x + CGFloat(index),
                                    y: origin.y,
                                    width: width,
                                    height: usedRect.size.height))
            .fill()
        }
      }
    }
  }
}

class MinimapTypeSetter: NSATSTypesetter {

  // Perform layout for the minimap. We don't layout the actual glyphs, but small rectangles representing the glyphs.
  //
  // This is a very simplified layout procedure that works for the specific setup of our code views. It completely
  // ignores some features of text views, such as areas to exclude, where `remainingRect` would be non-empty. It
  // currently also ignores all extra line and paragraph spacing and fails to call some methods that might adjust
  // layout decisions.
  override func layoutParagraph(at lineFragmentOrigin: UnsafeMutablePointer<NSPoint>) -> Int {

    let padding = currentTextContainer?.lineFragmentPadding ?? 0,
        width   = currentTextContainer?.size.width ?? 100

    // Determine the size of the rectangles to layout. (They are always twice as high as wide.)
    var fontHeight: CGFloat
    if let charIndex = layoutManager?.characterIndexForGlyph(at: paragraphGlyphRange.location),
       let font      = layoutManager?.textStorage?.attribute(.font, at: charIndex, effectiveRange: nil) as? NSFont
    {

      fontHeight = minimapFontSize(for: font.pointSize)

    } else { fontHeight = 2 }

    // We always leave one point of space between lines
    let lineHeight = fontHeight + 1,
        fontWidth  = fontHeight / 2   // NB: This is always going to be an integral number

    beginParagraph()

    if paragraphGlyphRange.length > 0 {   // non-empty line

      var remainingGlyphRange = paragraphGlyphRange

      while remainingGlyphRange.length > 0 {

        var lineFragmentRect = NSRect.zero
        var remainingRect = NSRect.zero    // NB: we don't care about this as we don't supporte exclusions

        beginLine(withGlyphAt: remainingGlyphRange.location)

        getLineFragmentRect(&lineFragmentRect,
                            usedRect: nil,
                            remaining: &remainingRect,
                            forStartingGlyphAt: remainingGlyphRange.location,
                            proposedRect: NSRect(origin: lineFragmentOrigin.pointee,
                                                 size: CGSize(width: width, height: lineHeight)),
                            lineSpacing: 0,
                            paragraphSpacingBefore: 0,
                            paragraphSpacingAfter: 0)

        lineFragmentRect.origin.x   += padding
        lineFragmentRect.size.width  = max(lineFragmentRect.size.width - 2 * padding, 0)

        // Determine how many glyphs we can fit into the `lineFragementRect`; must be at least one to make progress
        var numberOfGlyphs:       Int,
            lineGlyphRangeLength: Int
        var numberOfGlyphsThatFit = max(Int(floor(lineFragmentRect.width / fontWidth)), 1)

        // Add any elastic glyphs that follow (they can be compacted)
        while numberOfGlyphsThatFit < remainingGlyphRange.length
                && layoutManager?.propertyForGlyph(at: remainingGlyphRange.location + numberOfGlyphsThatFit) == .elastic
        {
          numberOfGlyphsThatFit += 1
        }

        if numberOfGlyphsThatFit < remainingGlyphRange.length { // we need a line break

          // Try to find a break point at a word boundary, by looking back. If we don't find one, take the largest
          // possible number of glyphs.
          //
          numberOfGlyphs = numberOfGlyphsThatFit
          glyphLoop: for glyphs in stride(from: numberOfGlyphsThatFit, to: 0, by: -1) {

            let glyphIndex = remainingGlyphRange.location + glyphs - 1

            var actualGlyphRange = NSRange(location: 0, length: 0)
            let charIndex = characterRange(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                           actualGlyphRange: &actualGlyphRange)
            if actualGlyphRange.location < glyphIndex { continue }  // we are not yet at a character boundary

            if layoutManager?.propertyForGlyph(at: glyphIndex) == .elastic
                && shouldBreakLine(byWordBeforeCharacterAt: charIndex.location)
            {

              // Found a valid break point
              numberOfGlyphs = glyphs
              break glyphLoop

            }
          }

          lineGlyphRangeLength = numberOfGlyphs

        } else {

          numberOfGlyphs       = remainingGlyphRange.length
          lineGlyphRangeLength = numberOfGlyphs + paragraphSeparatorGlyphRange.length

        }

        let lineFragementUsedRect = NSRect(origin: lineFragmentRect.origin,
                                           size: CGSize(width: CGFloat(numberOfGlyphs), height: fontHeight))

        // The glyph range covered by this line fragement — this may include the paragraph separator glyphs
        let remainingLength = remainingGlyphRange.length - numberOfGlyphs,
            lineGlyphRange  = NSRange(location: remainingGlyphRange.location, length: lineGlyphRangeLength)

        // The rest of what remains of this paragraph
        remainingGlyphRange = NSRange(location: remainingGlyphRange.location + numberOfGlyphs, length: remainingLength)

        setLineFragmentRect(lineFragmentRect,
                            forGlyphRange: lineGlyphRange,
                            usedRect: lineFragementUsedRect,
                            baselineOffset: 0)
        setLocation(NSPoint(x: 0, y: 0),
                    withAdvancements: nil, //Array(repeating: 1, count: numberOfGlyphs),
                    forStartOfGlyphRange: NSRange(location: lineGlyphRange.location, length: numberOfGlyphs))

        if remainingGlyphRange.length == 0 {

          setLocation(NSPoint(x: NSMaxX(lineFragementUsedRect), y: 0),
                      withAdvancements: nil,
                      forStartOfGlyphRange: paragraphSeparatorGlyphRange)
          setNotShownAttribute(true, forGlyphRange: paragraphSeparatorGlyphRange)

        }

        endLine(withGlyphRange: lineGlyphRange)

        lineFragmentOrigin.pointee.y += lineHeight

      }

    } else {  // empty line

      beginLine(withGlyphAt: paragraphSeparatorGlyphRange.location)

      var lineFragmentRect      = NSRect.zero,
          lineFragementUsedRect = NSRect.zero

      getLineFragmentRect(&lineFragmentRect,
                          usedRect: &lineFragementUsedRect,
                          forParagraphSeparatorGlyphRange: paragraphSeparatorGlyphRange,
                          atProposedOrigin: lineFragmentOrigin.pointee)

      setLineFragmentRect(lineFragmentRect,
                          forGlyphRange: paragraphSeparatorGlyphRange,
                          usedRect: lineFragementUsedRect,
                          baselineOffset: 0)
      setLocation(NSPoint.zero, withAdvancements: nil, forStartOfGlyphRange: paragraphSeparatorGlyphRange)
      setNotShownAttribute(true, forGlyphRange: paragraphSeparatorGlyphRange)

      endLine(withGlyphRange: paragraphSeparatorGlyphRange)

      lineFragmentOrigin.pointee.y += lineHeight

    }

    endParagraph()

    return NSMaxRange(paragraphSeparatorGlyphRange)
  }

  // Adjust the height of the fragment rectangles for empty lines.
  //
  override func getLineFragmentRect(_ lineFragmentRect: UnsafeMutablePointer<NSRect>,
                                    usedRect lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                                    forParagraphSeparatorGlyphRange paragraphSeparatorGlyphRange: NSRange,
                                    atProposedOrigin lineOrigin: NSPoint)
  {
    // Determine the size of the rectangles to layout. (They are always twice as high as wide.)
    var fontHeight: CGFloat
    if let glyphIndex = (paragraphSeparatorGlyphRange.length > 0   ? paragraphSeparatorGlyphRange.location : nil) ??
                        (paragraphSeparatorGlyphRange.location > 0 ? paragraphSeparatorGlyphRange.location - 1 : nil),
       let charIndex = layoutManager?.characterIndexForGlyph(at: glyphIndex),
       let font      = layoutManager?.textStorage?.attribute(.font, at: charIndex, effectiveRange: nil) as? NSFont
    {

      fontHeight = minimapFontSize(for: font.pointSize)

    } else { fontHeight = 2 }

    // We always leave one point of space between lines
    let lineHeight = fontHeight + 1

    super.getLineFragmentRect(lineFragmentRect,
                              usedRect: lineFragmentUsedRect,
                              forParagraphSeparatorGlyphRange: paragraphSeparatorGlyphRange,
                              atProposedOrigin: lineOrigin)
    lineFragmentRect.pointee.size.height     = lineHeight
    lineFragmentUsedRect.pointee.size.height = fontHeight
  }
}

/// Compute the size of the code view in number of characters such that we can still accommodate the minimap.
///
/// - Parameters:
///   - width: Overall width available for main and minimap code view *without* gutter and padding.
///   - font: The fixed pitch font of the main text view.
/// - Returns: The width of the code view in number of characters.
///
private func codeWidthInCharacters(for width: CGFloat, with font: NSFont) -> CGFloat {
  let minimapCharWidth = minimapFontSize(for: font.pointSize) / 2
  return floor(width / (font.maximumAdvancement.width + minimapCharWidth))
}

/// Compute the font size for the minimap from the font size of the main text view.
///
/// - Parameter fontSize: The font size of the main text view
/// - Returns: The font size for the minimap
///
/// The result is always divisible by two, to enable the use of full pixels for the font width while avoiding aspect
/// ratios that are too unbalanced.
///
private func minimapFontSize(for fontSize: CGFloat) -> CGFloat {
  return max(1, ceil(fontSize / 20)) * 2
}

#endif


// MARK: -
// MARK: Shared code

/// Customised layout manager for code layout.
///
class CodeLayoutManager: NSLayoutManager {

  weak var gutterView: GutterView?

  override func processEditing(for textStorage: NSTextStorage,
                               edited editMask: TextStorageEditActions,
                               range newCharRange: NSRange,
                               changeInLength delta: Int,
                               invalidatedRange invalidatedCharRange: NSRange) {
    super.processEditing(for: textStorage,
                         edited: editMask,
                         range: newCharRange,
                         changeInLength: delta,
                         invalidatedRange: invalidatedCharRange)

    // NB: Gutter drawing must be asynchronous, as the glyph generation that may be triggered in that process,
    //     is not permitted until the enclosing editing block has completed; otherwise, we run into an internal
    //     error in the layout manager.
    if let gutterView = gutterView {
      Dispatch.DispatchQueue.main.async { gutterView.invalidateGutter(forCharRange: invalidatedCharRange) }
    }
  }
}

/// Common code view actions triggered on a selection change.
///
private func selectionDidChange<TV: TextView>(_ textView: TV) {
  guard let layoutManager = textView.optLayoutManager,
        let textContainer = textView.optTextContainer,
        let codeStorage   = textView.optCodeStorage
        else { return }

  let visibleRect = textView.documentVisibleRect,
      glyphRange  = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: visibleRect,
                                             in: textContainer),
      charRange   = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

  if let location             = textView.insertionPoint,
     location > 0,
     let matchingBracketRange = codeStorage.matchingBracket(forLocationAt: location - 1, in: charRange)
  {
    textView.showFindIndicator(for: matchingBracketRange)
  }
}

/// Combine selection ranges into the smallest ranges encompassing them all.
///
private func combinedRanges(ranges: [NSValue]) -> NSRange {
  let actualranges = ranges.compactMap{ $0 as? NSRange }
  return actualranges.dropFirst().reduce(actualranges.first ?? NSRange(location: 0, length: 0)) {
    NSUnionRange($0, $1)
  }
}


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    CodeEditor(text: .constant("-- Hello World!"), with: haskellConfiguration)
  }
}
