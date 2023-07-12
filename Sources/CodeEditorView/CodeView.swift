//
//  CodeView.swift
//  
//
//  Created by Manuel M T Chakravarty on 05/05/2021.
//
//  This file contains both the macOS and iOS versions of the subclass for `NSTextView` and `UITextView`, respectively,
//  which forms the heart of the code editor.

import Combine
import SwiftUI

import Rearrange

import LanguageSupport


// MARK: -
// MARK: Message info

/// Information required to layout message views.
///
/// NB: This information is computed incrementally. We get the `lineFragementRect` from the text container during the
///     type setting processes. This indicates that the message layout may have to change (if it was already
///     computed), but at this point, we cannot determine the new geometry yet; hence, `geometry` will be `nil`.
///     The `geomtry` will be determined after text layout is complete.
///
struct MessageInfo {
  let view:               StatefulMessageView.HostingView
  var lineFragementRect:  CGRect                            // The *full* line fragement rectangle (incl. message)
  var geometry:           MessageView.Geometry?
  var colour:             OSColor                           // The category colour of the most severe category

  var topAnchorConstraint:   NSLayoutConstraint?
  var rightAnchorConstraint: NSLayoutConstraint?
}

/// Dictionary of message views.
///
typealias MessageViews = [LineInfo.MessageBundle.ID: MessageInfo]


#if os(iOS)

// MARK: -
// MARK: UIKit version

/// `UITextView` with a gutter
///
final class CodeView: UITextView {

  // Delegates
  fileprivate var codeViewDelegate:           CodeViewDelegate?
  fileprivate var codeStorageDelegate:        CodeStorageDelegate
  fileprivate let codeLayoutManagerDelegate = CodeLayoutManagerDelegate()  // shared between code view and minimap

  // Subviews
  fileprivate var gutterView: GutterView?

  /// The current highlighting theme
  ///
  var theme: Theme {
    didSet {
      font                                 = UIFont(name: theme.fontName, size: theme.fontSize)
      backgroundColor                      = theme.backgroundColour
      tintColor                            = theme.tintColour
      (textStorage as? CodeStorage)?.theme = theme
      gutterView?.theme                    = theme
      setNeedsDisplay(bounds)
    }
  }

  /// The current view layout.
  ///
  var viewLayout: CodeEditor.LayoutConfiguration {
    didSet {
      // Nothing to do, but that may change in the future
      textContainer.widthTracksTextView = viewLayout.wrapText
      textContainer.size.width          = viewLayout.wrapText ? frame.size.width : CGFloat.greatestFiniteMagnitude
      setNeedsLayout()
    }
  }

  /// Keeps track of the set of message views.
  ///
  var messageViews: MessageViews = [:]

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration, viewLayout: CodeEditor.LayoutConfiguration, theme: Theme) {

    self.viewLayout = viewLayout
    self.theme      = theme

    // Use custom components that are gutter-aware and support code-specific editing actions and highlighting.
    let codeLayoutManager         = CodeLayoutManager(),
        codeContainer             = CodeContainer(),
        codeStorage               = CodeStorage(theme: theme)
    codeStorage.addLayoutManager(codeLayoutManager)
    codeContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(codeContainer)
    codeLayoutManager.delegate = codeLayoutManagerDelegate

    codeStorageDelegate = CodeStorageDelegate(with: language)

    super.init(frame: frame, textContainer: codeContainer)
    codeContainer.textView = self

    // Set basic display and input properties
    font                   = theme.font
    backgroundColor        = theme.backgroundColour
    tintColor              = theme.tintColour
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
    codeStorage.delegate = self.codeStorageDelegate

    // Important for longer documents
    codeLayoutManager.allowsNonContiguousLayout =  true

    // Add a gutter view
    let gutterWidth = ceil(theme.fontSize) * 3,
        gutterView  = GutterView(frame: CGRect(x: 0,
                                               y: 0,
                                               width: gutterWidth,
                                               height: CGFloat.greatestFiniteMagnitude),
                                 textView: self,
                                 theme: theme,
                                 getMessageViews: { self.messageViews })
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

class CodeViewDelegate: NSObject, UITextViewDelegate {

  // Hooks for events
  //
  var textDidChange:      ((UITextView) -> ())?
  var selectionDidChange: ((UITextView) -> ())?
  var didScroll:          ((UIScrollView) -> ())?

  /// Caching the last set selected range.
  ///
  var oldSelectedRange: NSRange

  init(codeView: CodeView) {
    oldSelectedRange = codeView.selectedRange
  }

  // MARK: -
  // MARK: UITextViewDelegate protocol

  func textViewDidChange(_ textView: UITextView) { textDidChange?(textView) }

  func textViewDidChangeSelection(_ textView: UITextView) {
    guard let codeView = textView as? CodeView else { return }

    selectionDidChange?(textView)

    // NB: Invalidation of the two ranges needs to happen separately. If we were to union them, an insertion point
    //     (range length = 0) at the start of a line would be absorbed into the previous line, which results in a lack
    //     of invalidation of the line on which the insertion point is located.
    codeView.gutterView?.invalidateGutter(for: codeView.selectedRange)
    codeView.gutterView?.invalidateGutter(for: oldSelectedRange)
    oldSelectedRange = textView.selectedRange
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) { didScroll?(scrollView) }
}

#elseif os(macOS)

// MARK: -
// MARK: AppKit version

/// `NSTextView` with a gutter
///
final class CodeView: NSTextView {

  // Delegates
  fileprivate let codeViewDelegate =          CodeViewDelegate()
  fileprivate let codeLayoutManagerDelegate = CodeLayoutManagerDelegate()
  fileprivate var codeStorageDelegate:        CodeStorageDelegate

  // Subviews
  var gutterView:         GutterView?
  var minimapView:        NSTextView?
  var minimapGutterView:  GutterView?
  var documentVisibleBox: NSBox?
  var minimapDividerView: NSBox?

  // Notification observer
  var frameChangedNotificationObserver: NSObjectProtocol?

  /// Contains the line on which the insertion point was located, the last time the selection range got set (if the
  /// selection was an insertion point at all; i.e., it's length was 0).
  ///
  var oldLastLineOfInsertionPoint: Int? = 1

  /// The current highlighting theme
  ///
  var theme: Theme {
    didSet {
      font                                 = theme.font
      backgroundColor                      = theme.backgroundColour
      insertionPointColor                  = theme.cursorColour
      selectedTextAttributes               = [.backgroundColor: theme.selectionColour]
      (textStorage as? CodeStorage)?.theme = theme
      gutterView?.theme                    = theme
      minimapView?.backgroundColor         = theme.backgroundColour
      minimapGutterView?.theme             = theme
      documentVisibleBox?.fillColor        = theme.textColour.withAlphaComponent(0.1)
      minimapDividerView?.fillColor        = theme.backgroundColour.blended(withFraction: 0.15, of: .systemGray)!
      needsLayout = true
      tile()
      setNeedsDisplay(visibleRect)
    }
  }

  /// The current view layout.
  ///
  var viewLayout: CodeEditor.LayoutConfiguration {
    didSet {
      tile()
      needsLayout = true
      adjustScrollPositionOfMinimap()
    }
  }

  /// Keeps track of the set of message views.
  ///
  var messageViews: MessageViews = [:]
  
  /// For the consumption of the diagnostics stream.
  /// 
  private var diagnosticsCancellable: Cancellable?

  /// Holds the info popover if there is one.
  ///
  var infoPopover: InfoPopover?

  /// Holds the capabilities window if there is one.
  ///
  var capabilitiesWindow: CapabilitiesWindow?

  /// Designated initialiser for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration, viewLayout: CodeEditor.LayoutConfiguration, theme: Theme) {

    self.theme      = theme
    self.viewLayout = viewLayout

    // Use custom components that are gutter-aware and support code-specific editing actions and highlighting.
    let codeLayoutManager = CodeLayoutManager(),
        codeContainer     = CodeContainer(),
        codeStorage       = CodeStorage(theme: theme)
    codeStorage.addLayoutManager(codeLayoutManager)
    codeContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(codeContainer)
    codeLayoutManager.delegate = codeLayoutManagerDelegate

    codeStorageDelegate = CodeStorageDelegate(with: language)

    super.init(frame: frame, textContainer: codeContainer)

    // Set basic display and input properties
    font                                 = theme.font
    backgroundColor                      = theme.backgroundColour
    insertionPointColor                  = theme.cursorColour
    selectedTextAttributes               = [.backgroundColor: theme.selectionColour]
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
    usesFontPanel                        = false

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

    // Enable undo support
    allowsUndo = true

    // Add the view delegate
    delegate = codeViewDelegate

    // Add a text storage delegate that maintains a line map
    codeStorage.delegate = codeStorageDelegate

    // FIXME: We don't make much use of this yet, as some processes wait until there are no unlaid characters anymore — see #63.
    codeLayoutManager.allowsNonContiguousLayout =  true

    // Create the main gutter view
    let gutterView = GutterView(frame: CGRect.zero,
                                textView: self,
                                theme: theme,
                                getMessageViews: { self.messageViews },
                                isMinimapGutter: false)
    gutterView.autoresizingMask  = .none
    self.gutterView              = gutterView
    codeLayoutManager.gutterView = gutterView
    // NB: The gutter view is floating. We cannot add it now, as we don't have an `enclosingScrollView` yet.

    // Create the minimap with its own gutter, but sharing the code storage with the code view
    //
    let minimapLayoutManager = MinimapLayoutManager(),
        minimapView          = MinimapView(),
        minimapGutterView    = GutterView(frame: CGRect.zero,
                                          textView: minimapView,
                                          theme: theme,
                                          getMessageViews: { self.messageViews },
                                          isMinimapGutter: true),
        minimapDividerView   = NSBox()
    minimapView.codeView = self

    minimapDividerView.boxType     = .custom
    minimapDividerView.fillColor   = theme.backgroundColour.blended(withFraction: 0.15, of: .systemGray)!
    minimapDividerView.borderWidth = 0
    self.minimapDividerView = minimapDividerView
    // NB: The divider view is floating. We cannot add it now, as we don't have an `enclosingScrollView` yet.

    minimapView.textContainer?.replaceLayoutManager(minimapLayoutManager)
    codeStorage.addLayoutManager(minimapLayoutManager)
    minimapLayoutManager.delegate = codeLayoutManagerDelegate  // shared with code view

    minimapView.backgroundColor                     = backgroundColor
    minimapView.autoresizingMask                    = .none
    minimapView.isEditable                          = false
    minimapView.isSelectable                        = false
    minimapView.isHorizontallyResizable             = false
    minimapView.isVerticallyResizable               = true
    minimapView.textContainerInset                  = CGSize(width: 0, height: 0)
    minimapView.textContainer?.widthTracksTextView  = false    // we need to be able to control the size (see `tile()`)
    minimapView.textContainer?.heightTracksTextView = false
    minimapView.textContainer?.lineBreakMode        = .byWordWrapping
    self.minimapView = minimapView
    // NB: The minimap view is floating. We cannot add it now, as we don't have an `enclosingScrollView` yet.

    minimapView.addSubview(minimapGutterView)
    self.minimapGutterView = minimapGutterView

    minimapView.layoutManager?.typesetter = MinimapTypeSetter()

    let documentVisibleBox = NSBox()
    documentVisibleBox.boxType     = .custom
    documentVisibleBox.fillColor   = theme.textColour.withAlphaComponent(0.1)
    documentVisibleBox.borderWidth = 0
    minimapView.addSubview(documentVisibleBox)
    self.documentVisibleBox = documentVisibleBox

    maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

    // We need to re-tile the subviews whenever the frame of the text view changes.
    frameChangedNotificationObserver
      = NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification,
                                               object: self,
                                               queue: .main){ _ in
        self.tile()

        // NB: When resizing the window, where the text container doesn't completely fill the text view (i.e., the text
        //     is short), we need to explicitly redraw the gutter, as line wrapping may have channged, which affects
        //     line numbering.
        gutterView.needsDisplay = true
      }

    // Perform an initial tiling run when the view hierarchy has been set up.
    Task {
      tile(initial: true)
    }

    // Try to initialise a language service asynchronously.
    Task {
      if let languageService = await codeStorageDelegate.languageServiceInit() {

        // Report diagnostic messages as they come in
        diagnosticsCancellable = languageService.diagnostics
          .receive(on: DispatchQueue.main)
          .sink{ [self] messages in

          retractMessages()
          messages.forEach{ report(message: $0) }

        }
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    if let observer = frameChangedNotificationObserver { NotificationCenter.default.removeObserver(observer) }
  }

  override func setSelectedRanges(_ ranges: [NSValue], 
                                  affinity: NSSelectionAffinity,
                                  stillSelecting stillSelectingFlag: Bool)
  {
    let oldSelectedRanges = selectedRanges
    super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
    minimapView?.selectedRanges = selectedRanges    // minimap mirrors the selection of the main code view

    let lineOfInsertionPoint = insertionPoint.flatMap{ optLineMap?.lineOf(index: $0) }

    // If the insertion point changed lines, we need to redraw at the old and new location to fix the line highlighting.
    // NB: We retain the last line and not the character index as the latter may be inaccurate due to editing that let
    //     to the selected range change.
    if lineOfInsertionPoint != oldLastLineOfInsertionPoint {

      if let oldLine      = oldLastLineOfInsertionPoint,
         let oldLineRange = optLineMap?.lookup(line: oldLine)?.range
      {

        // We need to invalidate the whole background (incl message views); hence, we need to employ
        // `lineBackgroundRect(_:)`, which is why `NSLayoutManager.invalidateDisplay(forCharacterRange:)` is not
        // sufficient.
        layoutManager?.enumerateFragmentRects(forLineContaining: oldLineRange.location){ fragmentRect in

          self.setNeedsDisplay(self.lineBackgroundRect(fragmentRect))
        }
        minimapGutterView?.optLayoutManager?.invalidateDisplay(forCharacterRange: oldLineRange)

      }
      if let newLine      = lineOfInsertionPoint,
         let newLineRange = optLineMap?.lookup(line: newLine)?.range
      {

        // We need to invalidate the whole background (incl message views); hence, we need to employ
        // `lineBackgroundRect(_:)`, which is why `NSLayoutManager.invalidateDisplay(forCharacterRange:)` is not
        // sufficient.
        layoutManager?.enumerateFragmentRects(forLineContaining: newLineRange.location){ fragmentRect in

          self.setNeedsDisplay(self.lineBackgroundRect(fragmentRect))
        }
        minimapGutterView?.optLayoutManager?.invalidateDisplay(forCharacterRange: newLineRange)

      }
    }
    oldLastLineOfInsertionPoint = lineOfInsertionPoint

    // NB: The following needs to happen after calling `super`, as redrawing depends on the correctly set new set of
    //     ranges.

    // Needed as the selection affects line number highlighting.
    // NB: Invalidation of the old and new ranges needs to happen separately. If we were to union them, an insertion
    //     point (range length = 0) at the start of a line would be absorbed into the previous line, which results in
    //     a lack of invalidation of the line on which the insertion point is located.
    gutterView?.invalidateGutter(for: combinedRanges(ranges: oldSelectedRanges))
    gutterView?.invalidateGutter(for: combinedRanges(ranges: ranges))
    minimapGutterView?.invalidateGutter(for: combinedRanges(ranges: oldSelectedRanges))
    minimapGutterView?.invalidateGutter(for: combinedRanges(ranges: ranges))

    DispatchQueue.main.async {
      self.collapseMessageViews()
    }
  }

  override func drawBackground(in rect: NSRect) {
    super.drawBackground(in: rect)

    guard let layoutManager = layoutManager,
          let textContainer = textContainer
    else { return }

    let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: rect, in: textContainer),
        charRange  = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

    // If the selection is an insertion point, highlight the corresponding line
    if let location = insertionPoint, charRange.contains(location) || location == charRange.max {

      drawBackgroundHighlight(in: rect, forLineContaining: location, withColour: theme.currentLineColour)

    }

    // Highlight each line that has a message view
    for messageView in messageViews {

      let glyphRange = layoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: messageView.value.lineFragementRect,
                                                in: textContainer),
          index      = layoutManager.characterIndexForGlyph(at: glyphRange.location)

// This seems like a worthwhile optimisation, but sometimes we are called in a situation, where `charRange` computes
// to be the empty range although the whole visible area is being redrawn.
//      if charRange.contains(index) {

        drawBackgroundHighlight(in: rect,
                                forLineContaining: index,
                                withColour: messageView.value.colour.withAlphaComponent(0.1))

//      }
    }
  }

  /// Draw the background of an entire line of text with a highlight colour, including below any messages views.
  ///
  private func drawBackgroundHighlight(in rect: NSRect, forLineContaining charIndex: Int, withColour colour: NSColor) {
    guard let layoutManager = layoutManager else { return }

    colour.setFill()
    layoutManager.enumerateFragmentRects(forLineContaining: charIndex){ fragmentRect in

      let drawRect = self.lineBackgroundRect(fragmentRect).intersection(rect)
      if !drawRect.isNull { NSBezierPath(rect: drawRect).fill() }
    }
  }

  /// Compute the background rect from a line's fragement rect. On lines that contain a message view, the fragment
  /// rect doesn't cover the entire background. We, moreover, need to account for the space between the text container's
  /// right hand side and the divider of the minimap (if the minimap is visible).
  ///
  private func lineBackgroundRect(_ lineFragementRect: CGRect) -> CGRect {

    if let codeContainer = textContainer as? CodeContainer {

      // We start at x = 0 as it looks nicer in case we overscoll when horizontal scrolling is enabled (i.e., when lines
      // are not wrapped).
      return CGRect(origin: CGPoint(x: 0, y: lineFragementRect.origin.y) ,
                    size: CGSize(width: codeContainer.size.width + codeContainer.excessWidth,
                                 height: lineFragementRect.height))

    } else {

      return lineFragementRect

    }
  }

  /// Position and size the gutter and minimap and set the text container sizes and exclusion paths. Take the current
  /// view layout in `viewLayout` into account.
  ///
  /// * The main text view contains three subviews: (1) the main gutter on its left side, (2) the minimap on its right
  ///   side, and (3) a divider in between the code view and the minimap gutter.
  /// * Both the main text view and the minimap text view (or rather their text container) uses an exclusion path to
  ///   keep text out of the gutter view. The main text view is sized to avoid overlap with the minimap even without an
  ///   exclusion path.
  /// * The main text view and the minimap text view need to be able to accomodate exactly the same number of
  ///   characters, so that line breaking procceds in the exact same way.
  ///
  /// NB: We don't use a ruler view for the gutter on macOS to be able to use the same setup on macOS and iOS.
  ///
  @MainActor
  private func tile(initial: Bool = false) {
    guard let codeContainer = optTextContainer as? CodeContainer else { return }

    // We wait with tiling until the layout is done unless this is the initial tiling.
    if initial { actuallyTile() } else {

      whenLayoutDone { actuallyTile() }

    }

    // The actual tiling code.
    func actuallyTile() {

      // Add the floating views if they are not yet in the view hierachy.
      if let view = gutterView, view.superview == nil { enclosingScrollView?.addFloatingSubview(view, for: .horizontal) }
      if let view = minimapDividerView, view.superview == nil { enclosingScrollView?.addFloatingSubview(view, for: .horizontal) }
      if let view = minimapView, view.superview == nil { enclosingScrollView?.addFloatingSubview(view, for: .horizontal) }

      // Compute size of the main view gutter
      //
      let theFont                 = font ?? NSFont.systemFont(ofSize: 0),
          fontSize                = theFont.pointSize,
          fontWidth               = theFont.maximumAdvancement.width,  // NB: we deal only with fixed width fonts
          gutterWidthInCharacters = CGFloat(6),
          gutterWidth             = ceil(fontWidth * gutterWidthInCharacters),
          gutterSize              = CGSize(width: gutterWidth, height: frame.height),
          lineFragmentPadding     = CGFloat(5)

      let gutterWidthUpdate = gutterView?.frame.width != gutterWidth  // needed to avoid superflous exclusion path updates
      if gutterView?.frame.size != gutterSize { gutterView?.frame = CGRect(origin: .zero, size: gutterSize) }

      // Compute sizes of the minimap text view and gutter
      //
      let minimapFontWidth     = minimapFontSize(for: fontSize) / 2,
          minimapGutterWidth   = ceil(minimapFontWidth * gutterWidthInCharacters),
          dividerWidth         = CGFloat(1),
          minimapGutterRect    = CGRect(origin: CGPoint.zero,
                                        size: CGSize(width: minimapGutterWidth, height: frame.height)).integral,
          minimapExtras        = minimapGutterWidth + minimapFontWidth * 2 + dividerWidth,
          minimapFactor        = viewLayout.showMinimap ? CGFloat(1) : CGFloat(0),
          gutterWithPadding    = gutterWidth + lineFragmentPadding * 2,
          visibleWidth         = enclosingScrollView?.contentSize.width ?? frame.width,
          widthWithoutGutters  = visibleWidth - gutterWithPadding - minimapExtras * minimapFactor,
          numberOfCharacters   = codeWidthInCharacters(for: widthWithoutGutters,
                                                       with: theFont,
                                                       withMinimap: viewLayout.showMinimap),
          minimapWidth         = ceil(numberOfCharacters * minimapFontWidth + minimapGutterWidth + minimapFontWidth * 2),
          codeViewWidth        = visibleWidth - (minimapWidth + dividerWidth) * minimapFactor,
          excess               = widthWithoutGutters - ceil(numberOfCharacters * fontWidth)
      - (numberOfCharacters * minimapFontWidth) * minimapFactor,
      minimapX             = floor(visibleWidth - minimapWidth),
      minimapExclusionPath = OSBezierPath(rect: minimapGutterRect),
      minimapDividerRect   = CGRect(x: minimapX - dividerWidth, y: 0, width: dividerWidth, height: frame.height).integral

      minimapDividerView?.isHidden = !viewLayout.showMinimap
      minimapView?.isHidden        = !viewLayout.showMinimap
      if let minimapViewFrame = minimapView?.frame,
         viewLayout.showMinimap
      {

        if minimapDividerView?.frame != minimapDividerRect { minimapDividerView?.frame = minimapDividerRect }
        if minimapViewFrame.origin.x != minimapX || minimapViewFrame.width != minimapWidth {

          minimapView?.frame        = CGRect(x: minimapX,
                                             y: minimapViewFrame.origin.y,
                                             width: minimapWidth,
                                             height: minimapViewFrame.height)
          minimapGutterView?.frame  = minimapGutterRect
          minimapView?.minSize      = CGSize(width: minimapFontWidth, height: visibleRect.height)

        }
      }

      enclosingScrollView?.hasHorizontalScroller = !viewLayout.wrapText
      isHorizontallyResizable                    = !viewLayout.wrapText
      if !isHorizontallyResizable && frame.size.width != visibleWidth { frame.size.width = visibleWidth }  // don't update frames in vain

      // Set the text container area of the main text view to reach up to the minimap
      // NB: We use the `excess` width to capture the slack that arises when the window width admits a fractional
      //     number of characters. Adding the slack to the code view's text container size doesn't work as the line breaks
      //     of the minimap and main code view are then sometimes not entirely in sync.
      let codeContainerWidth = viewLayout.wrapText ? floor(codeViewWidth - excess) : CGFloat.greatestFiniteMagnitude
      if codeContainer.size.width != codeContainerWidth {
        codeContainer.size = NSSize(width: codeContainerWidth, height: CGFloat.greatestFiniteMagnitude)
      }

      // Never update the exclusion path in vain, as the update will invalidate the layout, which can lead to looping
      // behaviour if done in vain. To minimise updates, we also do not fix the height of the exclusion, but leave it
      // independent of the height of the container.
      if gutterWidthUpdate {
        codeContainer.exclusionPaths = [OSBezierPath(rect: CGRect(origin: .zero,
                                                                  size: CGSize(width: gutterWidth,
                                                                               height: .greatestFiniteMagnitude)))]
      }

      codeContainer.lineFragmentPadding = lineFragmentPadding
      codeContainer.excessWidth         = excess

      // Set the text container area of the minimap text view
      let minimapTextContainerWidth = viewLayout.wrapText ? minimapWidth : CGFloat.greatestFiniteMagnitude
      if minimapWidth != minimapView?.frame.width || minimapTextContainerWidth != minimapView?.textContainer?.size.width {

        minimapView?.textContainer?.exclusionPaths      = [minimapExclusionPath]
        minimapView?.textContainer?.size                = CGSize(width: minimapTextContainerWidth,
                                                                 height: CGFloat.greatestFiniteMagnitude)
        minimapView?.textContainer?.lineFragmentPadding = minimapFontWidth

      }

      // NB: We can't generally set the height of the box highlighting the document visible area here as it depends on
      //     the document and minimap height, which requires document layout to be completed. However, we still invoke
      //     `adjustScrollPositionOfMinimap()` here as it does little work and an intermediate update is visually
      //     more pleasing, especially when resizing the window or similar.
      adjustScrollPositionOfMinimap()

      needsDisplay = true
    }
  }

  /// Adjust the positioning of the floating views.
  ///
  func adjustScrollPosition() {
    adjustScrollPositionOfMinimap()
  }

  /// Sets the scrolling position of the minimap in dependence of the scroll position of the main code view.
  ///
  func adjustScrollPositionOfMinimap() {
    guard viewLayout.showMinimap else { return }

    whenLayoutDone { [self] in

      guard let minimapLayoutManager = minimapView?.layoutManager as? MinimapLayoutManager else { return }
      minimapLayoutManager.whenLayoutDone { [self] in

        let codeViewHeight = frame.size.height,
            codeHeight     = boundingRect()?.height ?? 0,
            minimapHeight  = minimapView?.boundingRect()?.height ?? 0,
            visibleHeight  = documentVisibleRect.size.height

        let scrollFactor: CGFloat
        if minimapHeight < visibleHeight || codeHeight <= visibleHeight { scrollFactor = 1 }
        else {

          scrollFactor = 1 - (minimapHeight - visibleHeight) / (codeHeight - visibleHeight)

        }

        // We box the positioning of the minimap at the top and the bottom of the code view (with the `max` and `min`
        // expessions. This is necessary as the minimap will otherwise be partially cut off by the enclosing clip view.
        // To get Xcode-like behaviour, where the minimap sticks to the top, it being a floating view is not sufficient.
        let newOriginY = floor(min(max(documentVisibleRect.origin.y * scrollFactor, 0),
                                   codeViewHeight - minimapHeight))
        if minimapView?.frame.origin.y != newOriginY { minimapView?.frame.origin.y = newOriginY }  // don't update frames in vain

        let minimapVisibleY      = documentVisibleRect.origin.y * minimapHeight / codeHeight,
            minimapVisibleHeight = visibleHeight * minimapHeight / codeHeight,
            documentVisibleFrame = CGRect(x: 0,
                                          y: minimapVisibleY,
                                          width: minimapView?.bounds.size.width ?? 0,
                                          height: minimapVisibleHeight).integral
        if documentVisibleBox?.frame != documentVisibleFrame { documentVisibleBox?.frame = documentVisibleFrame }  // don't update frames in vain
      }
    }
  }
}

class CodeViewDelegate: NSObject, NSTextViewDelegate {

  // Hooks for events
  //
  var textDidChange:      ((NSTextView) -> ())?
  var selectionDidChange: ((NSTextView) -> ())?

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

#endif


// MARK: -
// MARK: Shared code

extension CodeView {

  // MARK: Message views

  /// Update the layout of the specified message view if its geometry got invalidated by
  /// `CodeTextContainer.lineFragmentRect(forProposedRect:at:writingDirection:remaining:)`.
  ///
  fileprivate func layoutMessageView(identifiedBy id: UUID) {
    guard let codeLayoutManager = layoutManager as? CodeLayoutManager,
          let codeStorage       = textStorage as? CodeStorage,
          let codeContainer     = optTextContainer as? CodeContainer,
          let messageBundle     = messageViews[id]
    else { return }

    if messageBundle.geometry == nil {

      let glyphRange = codeLayoutManager.glyphRange(forBoundingRectWithoutAdditionalLayout: messageBundle.lineFragementRect,
                                                    in: codeContainer),
          charRange  = codeLayoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil),
          lineRange  = (codeStorage.string as NSString).lineRange(for: charRange),
          lineGlyphs = codeLayoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil),
          usedRect   = codeLayoutManager.lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil),
          lineRect   = codeLayoutManager.boundingRect(forGlyphRange: lineGlyphs, in: codeContainer)

      // Compute the message view geometry from the text layout information
      let geometry = MessageView.Geometry(lineWidth: messageBundle.lineFragementRect.width - usedRect.width,
                                          lineHeight: messageBundle.lineFragementRect.height,
                                          popupWidth:
                                            (codeContainer.size.width - MessageView.popupRightSideOffset) * 0.75,
                                          popupOffset: lineRect.height + 2)
      messageViews[id]?.geometry = geometry

      // Configure the view with the new geometry
      messageBundle.view.geometry = geometry
      if messageBundle.view.superview == nil {

        // Add the messages view
        addSubview(messageBundle.view)
        let topOffset           = textContainerOrigin.y + messageBundle.lineFragementRect.minY,
            topAnchorConstraint = messageBundle.view.topAnchor.constraint(equalTo: self.topAnchor,
                                                                          constant: topOffset)
        let leftOffset            = textContainerOrigin.x + messageBundle.lineFragementRect.maxX
                                                          + codeContainer.excessWidth,
            rightAnchorConstraint = messageBundle.view.rightAnchor.constraint(equalTo: self.leftAnchor,
                                                                              constant: leftOffset)
        messageViews[id]?.topAnchorConstraint   = topAnchorConstraint
        messageViews[id]?.rightAnchorConstraint = rightAnchorConstraint
        NSLayoutConstraint.activate([topAnchorConstraint, rightAnchorConstraint])


      } else {

        // Update the messages view constraints
        let topOffset  = textContainerOrigin.y + messageBundle.lineFragementRect.minY,
            leftOffset = textContainerOrigin.x + messageBundle.lineFragementRect.maxX + codeContainer.excessWidth
        messageViews[id]?.topAnchorConstraint?.constant   = topOffset
        messageViews[id]?.rightAnchorConstraint?.constant = leftOffset

      }
    }
  }

  /// Adds a new message to the set of messages for this code view.
  ///
  func report(message: TextLocated<Message>) {
    guard let messageBundle = codeStorageDelegate.add(message: message) else { return }

    updateMessageView(for: messageBundle, at: message.location.zeroBasedLine)
  }

  /// Removes a given message. If it doesn't exist, do nothing. This function is quite expensive.
  ///
  func retract(message: Message) {
    guard let (messageBundle, line) = codeStorageDelegate.remove(message: message) else { return }

    updateMessageView(for: messageBundle, at: line)
  }

  /// Given a new or updated message bundle, update the corresponding message view appropriately. This includes covering
  /// the two special cases, where we create a new view or we remove a view for good (as its last message got deleted).
  ///
  /// NB: The `line` argument is zero-based.
  ///
  private func updateMessageView(for messageBundle: LineInfo.MessageBundle, at line: Int) {
    guard let charRange = codeStorageDelegate.lineMap.lookup(line: line)?.range else { return }

    removeMessageViews(withIDs: [messageBundle.id])

    // If we removed the last message of this view, we don't need to create a new version
    if messageBundle.messages.isEmpty { return }

    // TODO: CodeEditor needs to be parameterised by message theme
    let messageTheme = Message.defaultTheme

    let messageView = StatefulMessageView.HostingView(messages: messageBundle.messages,
                                                      theme: messageTheme,
                                                      geometry: MessageView.Geometry(lineWidth: 100,
                                                                                     lineHeight: 15,
                                                                                     popupWidth: 300,
                                                                                     popupOffset: 16),
                                                      fontSize: font?.pointSize ?? OSFont.systemFontSize,
                                                      colourScheme: theme.colourScheme),
        principalCategory = messagesByCategory(messageBundle.messages)[0].key,
        colour            = messageTheme(principalCategory).colour

    messageViews[messageBundle.id] = MessageInfo(view: messageView,
                                                 lineFragementRect: CGRect.zero,
                                                 geometry: nil,
                                                 colour: colour)

    // We invalidate the layout of the line where the message belongs as their may be less space for the text now and
    // because the layout process for the text fills the `lineFragmentRect` property of the above `MessageInfo`.
    optLayoutManager?.invalidateLayout(forCharacterRange: charRange, actualCharacterRange: nil)
    self.optLayoutManager?.invalidateDisplay(forCharacterRange: charRange)
    gutterView?.invalidateGutter(for: charRange)
  }

  /// Remove the messages associated with a specified range of lines.
  ///
  /// - Parameter onLines: The line range where messages are to be removed. If `nil`, all messages on this code view are
  ///     to be removed.
  ///
  func retractMessages(onLines lines: Range<Int>? = nil) {
    var messageIds: [LineInfo.MessageBundle.ID] = []

    // Remove all message bundles in the line map and collect their ids for subsequent view removal.
    for line in lines ?? 1..<codeStorageDelegate.lineMap.lines.count {

      if let messageBundle = codeStorageDelegate.messages(at: line) {

        messageIds.append(messageBundle.id)
        codeStorageDelegate.removeMessages(at: line)

      }

    }

    // Make sure to remove all views that are still around if necessary.
    if lines == nil { removeMessageViews() } else { removeMessageViews(withIDs: messageIds) }
  }

  /// Remove the message views with the given ids.
  ///
  /// - Parameter ids: The IDs of the message bundles that ought to be removed. If `nil`, remove all.
  ///
  /// IDs that do not have no associated message view cause no harm.
  ///
  fileprivate func removeMessageViews(withIDs ids: [LineInfo.MessageBundle.ID]? = nil) {

    for id in ids ?? Array<LineInfo.MessageBundle.ID>(messageViews.keys) {

      if let info = messageViews[id] { info.view.removeFromSuperview() }
      messageViews.removeValue(forKey: id)

    }
  }

  /// Ensure that all message views are in their collapsed state.
  ///
  func collapseMessageViews() {
    for messageView in messageViews {
      messageView.value.view.unfolded = false
    }
  }

}


// MARK: Code container

class CodeContainer: NSTextContainer {

  #if os(iOS)
  weak var textView: UITextView?
  #endif

  /// This is horizontal space of the code view beyond the width of the text container, which we need to maintain
  /// in some configurations with the minimap to synchronise line breaks between code view and minimap. The text
  /// container needs to be aware of the excess, to be able to determine complete rectangles for the drawing of
  /// background elements, such as line highlights.
  ///
  var excessWidth: CGFloat = 0

  override func lineFragmentRect(forProposedRect proposedRect: CGRect,
                                 at characterIndex: Int,
                                 writingDirection baseWritingDirection: NSWritingDirection,
                                 remaining remainingRect: UnsafeMutablePointer<CGRect>?)
  -> CGRect
  {
    let calculatedRect = super.lineFragmentRect(forProposedRect: proposedRect,
                                                at: characterIndex,
                                                writingDirection: baseWritingDirection,
                                                remaining: remainingRect)

    guard let codeView    = textView as? CodeView,
          let codeStorage = layoutManager?.textStorage as? CodeStorage,
          let delegate    = codeStorage.delegate as? CodeStorageDelegate,
          let line        = delegate.lineMap.lineOf(index: characterIndex),
          let oneLine     = delegate.lineMap.lookup(line: line),
          characterIndex == oneLine.range.location    // we are only interested in the first line fragment of a line
    else { return calculatedRect }

    // On lines that contain messages, we reduce the width of the available line fragement rect such that there is
    // always space for a minimal truncated message (provided the text container is wide enough to accomodate that).
    if let messageBundleId = delegate.messages(at: line)?.id,
       calculatedRect.width > 2 * MessageView.minimumInlineWidth
    {

      codeView.messageViews[messageBundleId]?.lineFragementRect = calculatedRect
      codeView.messageViews[messageBundleId]?.geometry = nil                      // invalidate the geometry

      // To fully determine the layout of the message view, typesetting needs to complete for this line; hence, we defer
      // configuring the view.
      DispatchQueue.main.async { codeView.layoutMessageView(identifiedBy: messageBundleId) }

      return CGRect(origin: calculatedRect.origin,
                    size: CGSize(width: calculatedRect.width - MessageView.minimumInlineWidth,
                                 height: calculatedRect.height))

    } else { return calculatedRect }
  }
}


// MARK: Code layout manager

/// Customised layout manager for code layout.
///
class CodeLayoutManager: NSLayoutManager {

  weak var gutterView: GutterView?

  /// Action to execute when layout completes.
  ///
  var postLayoutAction: (() -> ())?

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

    gutterView?.invalidateGutter(for: invalidatedCharRange)

    // Remove all messages in the edited range.
    if let codeStorageDelegate = textStorage.delegate as? CodeStorageDelegate,
       let codeView            = gutterView?.textView as? CodeView
    {
      codeView.removeMessageViews(withIDs: codeStorageDelegate.lastEvictedMessageIDs)
    }
  }

  // We add the area excluded to accomodate the gutter to the returned rectangle as text view otherwise pushes the used
  // area of the text container into the exluded area when the text view gets compressed below the width of the text
  // container including the excluded area.
  override func usedRect(for container: NSTextContainer) -> CGRect {
    let rect = super.usedRect(for: container)
    return CGRect(origin: .zero, size: CGSize(width: rect.maxX, height: rect.height))
  }

  /// Add an action to be executed when layout finished.
  ///
  /// - Parameter action: The action that shoudl run after layout finished.
  ///
  /// NB: If multiple actions are registered, they are executed in the order in which they were registered.
  ///
  private func registerPostLayout(action: @escaping () -> ()) {
    let previousPostLayoutAction = postLayoutAction
    postLayoutAction = { previousPostLayoutAction?(); action() }  // we execute in the order of registration
  }

  /// Execute the given action when layout is complete. That may be right away or waiting for layout to complete.
  ///
  /// - Parameter action: The action that should be done if and when layout is complete.
  ///
  func whenLayoutDone(action: @escaping () -> ()) {
    if hasUnlaidCharacters { registerPostLayout(action: action) } else { action() }
  }
}

extension CodeView {

  /// Execute the given action when layout is complete. That may be right away or waiting for layout to complete.
  ///
  /// - Parameter action: The action that should be done if and when layout is complete.
  ///
  func whenLayoutDone(action: @escaping () -> ()) {
    guard let codeLayoutManager = layoutManager as? CodeLayoutManager else { action(); return }

    codeLayoutManager.whenLayoutDone(action: action)
  }
}

class CodeLayoutManagerDelegate: NSObject, NSLayoutManagerDelegate {

  func layoutManager(_ layoutManager: NSLayoutManager,
                     didCompleteLayoutFor textContainer: NSTextContainer?,
                     atEnd layoutFinishedFlag: Bool)
  {
    guard let layoutManager = layoutManager as? CodeLayoutManager else { return }

    if layoutFinishedFlag {

      layoutManager.gutterView?.layoutFinished()
      layoutManager.postLayoutAction?()
      layoutManager.postLayoutAction = nil

    }
  }
}


// MARK: Selection change management

/// Common code view actions triggered on a selection change.
///
func selectionDidChange<TV: TextView>(_ textView: TV) {
  guard let codeStorage  = textView.optCodeStorage,
        let visibleLines = textView.documentVisibleLines
  else { return }

  if let location             = textView.insertionPoint,
     let matchingBracketRange = codeStorage.matchingBracket(at: location, in: visibleLines)
  {
    textView.showFindIndicator(for: matchingBracketRange)
  }
}


// MARK: NSRange

/// Combine selection ranges into the smallest ranges encompassing them all.
///
private func combinedRanges(ranges: [NSValue]) -> NSRange {
  let actualranges = ranges.compactMap{ $0 as? NSRange }
  return actualranges.dropFirst().reduce(actualranges.first ?? .zero) {
    NSUnionRange($0, $1)
  }
}


