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
fileprivate class CodeViewWithGutter: UITextView {

  private var gutterView:          GutterView?
  private var codeStorageDelegate: CodeStorageDelegate?

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration) {

    // Use a custom layout manager that is gutter-aware
    let codeLayoutManager = CodeLayoutManager(),
        textContainer     = NSTextContainer(),
        textStorage       = NSTextStorage()
    textStorage.addLayoutManager(codeLayoutManager)
    textContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(textContainer)

    super.init(frame: frame, textContainer: textContainer)

    // Set basic display and input properties
    font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
    backgroundColor        = UIColor.systemBackground
    autocapitalizationType = .none
    autocorrectionType     = .no
    spellCheckingType      = .no
    smartQuotesType        = .no
    smartDashesType        = .no
    smartInsertDeleteType  = .no

    // Add a text storage delegate that maintains a line map
    self.codeStorageDelegate = CodeStorageDelegate(with: language)
    textStorage.delegate     = self.codeStorageDelegate

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
    let textView = CodeViewWithGutter(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                                      with: language)

    textView.text     = text
    textView.delegate = context.coordinator
    return textView
  }

  public func updateUIView(_ textView: UITextView, context: Context) {
    if text != textView.text { textView.text = text }  // Hoping for the string comparison fast path...
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator: NSObject, UITextViewDelegate {
    @Binding var text: String

    init(_ text: Binding<String>) {
      self._text = text
    }

    public func textViewDidChange(_ textView: UITextView) {
      self.text = textView.text
    }
  }
}


#elseif os(macOS)

// MARK: -
// MARK: AppKit version

/// `NSTextView` with a gutter
///
fileprivate class CodeViewWithGutter: NSTextView {

  private var gutterView:          GutterView?
  private var codeStorageDelegate: CodeStorageDelegate?

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect, with language: LanguageConfiguration) {

    // Use a custom layout manager that is gutter-aware
    let codeLayoutManager = CodeLayoutManager(),
        textContainer     = NSTextContainer(),
        textStorage       = NSTextStorage()
    textStorage.addLayoutManager(codeLayoutManager)
    textContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(textContainer)

    super.init(frame: frame, textContainer: textContainer)

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

    // Add a text storage delegate that maintains a line map
    self.codeStorageDelegate = CodeStorageDelegate(with: language)
    textStorage.delegate     = self.codeStorageDelegate

    // Add a gutter view
    let gutterWidth = (font?.pointSize ?? NSFont.systemFontSize) * 3,
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

  override func layout() {
    super.layout()
    gutterView?.frame.size.height = frame.size.height
  }
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
    let textView = CodeViewWithGutter(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                                      with: language)
    textView.minSize                 = CGSize(width: 0, height: scrollView.contentSize.height)
    textView.maxSize                 = CGSize(width: CGFloat.greatestFiniteMagnitude,
                                              height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable   = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask        = .width

    // Embedd text view in scroll view
    scrollView.documentView = textView

    textView.string   = text
    textView.delegate = context.coordinator
    return scrollView
  }

  public func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    if text != textView.string { textView.string = text }  // Hoping for the string comparison fast path...
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String

    init(_ text: Binding<String>) {
      self._text = text
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }

    }

    public func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }

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


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
      CodeEditor(text: .constant("-- Hello World!"), with: haskellConfiguration)
    }
  }
}
