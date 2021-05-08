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

/// SwiftUI code editor based on TextKit
///
public struct CodeEditor: NSViewRepresentable {
  let language: LanguageConfiguration
//  let messagePublisher: PassthroughSubject<Message,NSError>

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
    textView.setSelectedRange(NSRange(location: 0, length: 0))

    // The minimap needs to be vertically positioned in dependence on the scroll position of the main code view.
    context.coordinator.liveScrollNotificationObserver
      = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView,
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

#endif


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    CodeEditor(text: .constant("-- Hello World!"), with: haskellConfiguration)
  }
}
