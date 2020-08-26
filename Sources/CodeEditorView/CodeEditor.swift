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
  var text: Binding<String>

  public init(text: Binding<String>) {
    self.text = text
  }

  public func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.text = text.wrappedValue
    textView.delegate = context.coordinator
    return textView
  }

  public func updateUIView(_ uiView: UITextView, context: Context) {
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator(text)
  }

  public final class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>

    init(_ text: Binding<String>) {
      self.text = text
    }

    public func textViewDidChange(_ textView: UITextView) {
      self.text.wrappedValue = textView.text
    }
  }
}

#elseif os(macOS)

// MARK: -
// MARK: AppKit version

public struct CodeEditor: NSViewRepresentable {
  var text: Binding<String>

  public init(text: Binding<String>) {
    self.text = text
  }

  public func makeNSView(context: Context) -> NSTextView {
    let textView = NSTextView()
    textView.textStorage?.setAttributedString(NSAttributedString(string: text.wrappedValue))
    return textView
  }

  public func updateNSView(_ nsView: NSTextView, context: Context) {
  }
}

#endif

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
      CodeEditor(text: .constant("Hello World!"))
      TextEditor(text: .constant("bla"))
    }
  }
}
