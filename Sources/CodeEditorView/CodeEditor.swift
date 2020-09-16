//
//  CodeEditor.swift
//
//  Created by Manuel M T Chakravarty on 23/08/2020.
//
// SwiftUI 'CodeEditor' view

import SwiftUI


#if os(iOS)

// MARK: -
// MARK: UIKit version

public struct CodeEditor: UIViewRepresentable {
  @Binding var text: String

  public init(text: Binding<String>) {
    self._text = text
  }

  public func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.text = text
    textView.delegate = context.coordinator
    return textView
  }

  public func updateUIView(_ uiView: UITextView, context: Context) {
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

public struct CodeEditor: NSViewRepresentable {
  @Binding var text: String

  public init(text: Binding<String>) {
    self._text = text
  }

  public func makeNSView(context: Context) -> NSTextView {
    let textView = NSTextView()
    textView.textStorage?.setAttributedString(NSAttributedString(string: text))
    return textView
  }

  public func updateNSView(_ nsView: NSTextView, context: Context) {
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator($text)
  }

  public final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String

    init(_ text: Binding<String>) {
      self._text = text
    }

    public func textViewDidChange(_ textView: NSTextView) {
      self.text = textView.textStorage?.string ?? "" 
    }
  }
}

#endif

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
      CodeEditor(text: .constant("Hello World!"))
    }
  }
}
