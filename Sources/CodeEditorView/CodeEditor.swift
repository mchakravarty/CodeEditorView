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

  private var gutterView:          GutterView?
  private var codeViewDelegate:    CodeViewDelegate?
  private var codeStorageDelegate: CodeStorageDelegate?

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
    codeViewDelegate = CodeViewDelegate()
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


  // MARK: -
  // MARK: UITextViewDelegate protocol

  func textDidChange(_ textView: UITextView) { textDidChange?(textView) }

  func textViewDidChangeSelection(_ textView: UITextView) { selectionDidChange?(textView) }
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
  private var codeViewDelegate:    CodeViewDelegate?
  private var codeStorageDelegate: CodeStorageDelegate?

  // Subviews
  private var gutterView:        GutterView?
  private var minimapView:       NSTextView?
  private var minimapGutterView: GutterView?

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
    let minimapView       = NSTextView(),
        minimapGutterView = GutterView(frame: CGRect.zero, textView: minimapView, isMinimapGutter: true)

    minimapView.layoutManager?.replaceTextStorage(codeStorage)
    minimapView.autoresizingMask = .none
    minimapView.isEditable       = false
    minimapView.isSelectable     = false
    addSubview(minimapView)
    self.minimapView = minimapView
    minimapView.addSubview(minimapGutterView)
    self.minimapGutterView = minimapGutterView

    doLayout()
    
    minimapView.backgroundColor = .darkGray
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    doLayout()
  }

  /// Position and size the gutter and minimap and set the exclusion paths.
  ///
  private func doLayout() {

    // Configure the main view gutter
    //
    let fontSize            = font?.pointSize ?? NSFont.systemFontSize,
        gutterWidth         = fontSize * 3,
        gutterRect          = CGRect(origin: CGPoint.zero, size: CGSize(width: gutterWidth, height: frame.height)),
        gutterExclusionPath = NSBezierPath(rect: gutterRect)
    gutterView?.frame = gutterRect

    // Configure the minimap text view and gutter
    //
    let currentMinimapWidth  = minimapWidth(from: frame.width, at: fontSize),
        codeViewWidth        = frame.width - currentMinimapWidth,
        minimapGutterWidth   = minimapFontSize(for: fontSize) * 3,
        minimapRect          = CGRect(x: codeViewWidth, y: 0, width: currentMinimapWidth, height: frame.height),
        minimapGutterRect    = CGRect(origin: CGPoint.zero,
                                      size: CGSize(width: minimapGutterWidth, height: frame.height)),
        minimapExclusionPath = NSBezierPath(rect: minimapRect),
        minimapGutterExclusionPath = NSBezierPath(rect: minimapGutterRect)

    minimapView?.frame       = minimapRect
    minimapGutterView?.frame = minimapGutterRect

    optTextContainer?.exclusionPaths              = [gutterExclusionPath, minimapExclusionPath]
    minimapView?.optTextContainer?.exclusionPaths = [minimapGutterExclusionPath]
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
    textView.minSize                 = CGSize(width: 0, height: scrollView.contentSize.height)
    textView.maxSize                 = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                              height: CGFloat.greatestFiniteMagnitude)
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

    init(_ text: Binding<String>) {
      self._text = text
    }

    func textDidChange(_ textView: NSTextView) {
      self.text = textView.string
    }
  }
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

/// Compute the size of the minimap view from the overall size available.
///
/// - Parameters:
///   - width: This is the overall available width of the main text view together with the minimap and including
///            gutters.
///   - fontSize: The font size of the main text view.
/// - Returns: The width of the minimap including the minimap gutter.
///
private func minimapWidth(from width: CGFloat, at fontSize: CGFloat) -> CGFloat {
  return ceil(width / (minimapFontSize(for: fontSize) / 2 * 10 + 1))
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

// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    CodeEditor(text: .constant("-- Hello World!"), with: haskellConfiguration)
  }
}
