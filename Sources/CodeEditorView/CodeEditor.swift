//
//  CodeEditor.swift
//
//  Created by Manuel M T Chakravarty on 23/08/2020.
//
//  SwiftUI 'CodeEditor' view

import SwiftUI


/// SwiftUI code editor based on TextKit.
///
/// SwiftUI `Environment`:
/// * Environment value `codeEditorTheme`: determines the code highlighting theme to use
/// * Text-related values: affect the rendering of message views
///
public struct CodeEditor {

  /// Specification of the editor layout.
  ///
  public struct LayoutConfiguration {

    /// Show the minimap if possible. (Currently only supported on macOS.)
    ///
    public let showMinimap: Bool

    /// Creates a layout configuration.
    ///
    /// - Parameter showMinimap: Whether to show the minimap if possible.
    ///
    public init(showMinimap: Bool) {
      self.showMinimap = showMinimap
    }
  }

  let language: LanguageConfiguration
  let layout  : LayoutConfiguration

  @Binding private var text:     String
  @Binding private var messages: Set<Located<Message>>

  /// Creates a fully configured code editor.
  ///
  /// - Parameters:
  ///   - text: Binding to the edited text.
  ///   - messages: Binding to the messages reported at the appropriate lines of the edited text. NB: Messages
  ///               processing and display is relatively expensive. Hence, there should only be a limited number of
  ///               simultaneous messages and they shouldn't change to frequently.
  ///   - language: Language configuration for highlighting and similar.
  ///
  public init(text: Binding<String>,
              messages: Binding<Set<Located<Message>>>,
              language: LanguageConfiguration = .none)
  {
    self._text     = text
    self._messages = messages
    self.language  = language
  }

  public class _Coordinator {
    @Binding var text: String

    /// This is the last observed value of `messages`, to enable us to compute the difference in the next update.
    ///
    fileprivate var lastMessages: Set<Located<Message>> = Set()

    init(_ text: Binding<String>) {
      self._text = text
    }
  }
}

#if os(iOS)

// MARK: -
// MARK: UIKit version

extension CodeEditor: UIViewRepresentable {
  public func makeUIView(context: Context) -> UITextView {
    let codeView = CodeView(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                            with: language, theme: context.environment[CodeEditorTheme])

    codeView.text = text
    if let delegate = codeView.delegate as? CodeViewDelegate {
      delegate.textDidChange      = context.coordinator.textDidChange
      delegate.selectionDidChange = selectionDidChange
    }

    // Report the initial message set
    DispatchQueue.main.async { updateMessages(in: codeView, with: context) }

    return codeView
  }

  public func updateUIView(_ textView: UITextView, context: Context) {
    guard let codeView = textView as? CodeView else { return }
    
    let theme = context.environment[CodeEditorTheme]

    if text != textView.text { textView.text = text }  // Hoping for the string comparison fast path...
    updateMessages(in: codeView, with: context)
    if theme.id != codeView.theme.id { codeView.theme = theme }
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator: _Coordinator {
    func textDidChange(_ textView: UITextView) {
      self.text = textView.text
    }
  }
}

#elseif os(macOS)

// MARK: -
// MARK: AppKit version

extension CodeEditor: NSViewRepresentable {
  public func makeNSView(context: Context) -> NSScrollView {

    // Set up scroll view
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    scrollView.borderType          = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalRuler  = false
    scrollView.autoresizingMask    = [.width, .height]

    // Set up text view with gutter
    let codeView = CodeView(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                            with: language, theme: context.environment[CodeEditorTheme])
    codeView.isVerticallyResizable   = true
    codeView.isHorizontallyResizable = false
    codeView.autoresizingMask        = .width

    // Embedd text view in scroll view
    scrollView.documentView = codeView

    codeView.string = text
    if let delegate = codeView.delegate as? CodeViewDelegate {
      delegate.textDidChange      = context.coordinator.textDidChange
      delegate.selectionDidChange = selectionDidChange
    }
    codeView.setSelectedRange(NSRange(location: 0, length: 0))

    // The minimap needs to be vertically positioned in dependence on the scroll position of the main code view.
    context.coordinator.liveScrollNotificationObserver
      = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView,
                                               queue: .main){ _ in codeView.adjustScrollPositionOfMinimap() }

    // Report the initial message set
    DispatchQueue.main.async { updateMessages(in: codeView, with: context) }

    return scrollView
  }

  public func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let codeView = nsView.documentView as? CodeView else { return }

    let theme = context.environment[CodeEditorTheme]
    updateMessages(in: codeView, with: context)
    if text != codeView.string { codeView.string = text }  // Hoping for the string comparison fast path...
    if theme.id != codeView.theme.id { codeView.theme = theme }
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator: _Coordinator {
    var liveScrollNotificationObserver: NSObjectProtocol?

    deinit {
      if let observer = liveScrollNotificationObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func textDidChange(_ textView: NSTextView) {
      self.text = textView.string
    }
  }
}

#endif


// MARK: -
// MARK: Shared code

extension CodeEditor {
  /// Update messages for a code view in the given context.
  ///
  private func updateMessages(in codeView: CodeView, with context: Context) {
    update(oldMessages: context.coordinator.lastMessages, to: messages, in: codeView)
    context.coordinator.lastMessages = messages
  }

  /// Update the message set of the given code view.
  ///
  private func update(oldMessages: Set<Located<Message>>,
                      to updatedMessages: Set<Located<Message>>,
                      in codeView: CodeView)
  {
    let messagesToAdd    = updatedMessages.subtracting(oldMessages),
        messagesToRemove = oldMessages.subtracting(updatedMessages)

    for message in messagesToRemove { codeView.retract(message: message.entity) }
    for message in messagesToAdd    { codeView.report(message: message) }
  }
}

/// Environment key for the current code editor theme.
///
public struct CodeEditorTheme: EnvironmentKey {
  public static var defaultValue: Theme = Theme.defaultLight
}

extension EnvironmentValues {
  /// The current code editor theme.
  ///
  public var codeEditorTheme: Theme {
    get { self[CodeEditorTheme.self] }
    set { self[CodeEditorTheme.self] = newValue }
  }
}


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    CodeEditor(text: .constant("-- Hello World!"), messages: .constant(Set()), language: .haskell)
  }
}
