//
//  CodeEditor.swift
//
//  Created by Manuel M T Chakravarty on 23/08/2020.
//
//  SwiftUI 'CodeEditor' view

import SwiftUI

// TODO: Subclass NSTextStorage or provide an appropriate delegate to keep all the extra info on line maps, tokens maps, etc
// To get a small overview rendering of the text like in Xcode and Sublime, use two 'NSLayoutManager's (and two 'NSTextContainer's and two 'NSTextView's) with one 'NSTextStorage' — see "TextKit Best Practices" (WWDC18) and "Advanced Cocoa Text Tips and Tricks" (WWDC10).
// To change the rendering of an entire paragraph (eg, code block in a markdown document), use a custom paragraph style with a subclass of 'NSTextBlock' — see "TextKit Best Practices" (WWDC18).

let gutterWidth: CGFloat = 30 // FIXME: would need to dynamically adjust to gutter view

#if os(iOS)


// MARK: -
// MARK: UIKit version

/// `UITextView` with a gutter
///
fileprivate class UITextViewWithGutter: UITextView {

  private var gutterView: GutterView?

  override func willMove(toWindow newWindow: UIWindow?) {
    guard gutterView == nil else { return }

    let gutterView = GutterView(frame: CGRect(x: 0, y: 0, width: gutterWidth, height: CGFloat.greatestFiniteMagnitude),
                                textView: self)
    addSubview(gutterView)
    self.gutterView = gutterView
  }

  override func layoutSubviews() {
    gutterView?.frame.size.height = contentSize.height
  }
}

/// SwiftUI code editor based on TextKit
///
public struct CodeEditor: UIViewRepresentable {
  @Binding var text: String

  public init(text: Binding<String>) {
    self._text = text
  }

  public func makeUIView(context: Context) -> UITextView {
    let textView = UITextViewWithGutter()

    textView.text     = text
    textView.delegate = context.coordinator
    return textView
  }

  public func updateUIView(_ uiView: UITextView, context: Context) {
    uiView.text = text
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

/// SwiftUI code editor based on TextKit
///
public struct CodeEditor: NSViewRepresentable {
  @Binding var text: String

  public init(text: Binding<String>) {
    self._text = text
  }

  public func makeNSView(context: Context) -> NSTextView {
    // the NSTextContainer is unowned(unsafe); who owns it?
    let textView = NSTextView()
    textView.string = text
//    textView.textStorage?.setAttributedString(NSAttributedString(string: text))
    return textView
  }

  public func updateNSView(_ nsView: NSTextView, context: Context) {
    // FIXME: not good (by itself) as it kills all highlighting
    nsView.string = text
//    nsView.textStorage?.setAttributedString(NSAttributedString(string: text))
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

// MARK: -
// MARK: Shared code


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
      CodeEditor(text: .constant("Hello World!"))
    }
  }
}
