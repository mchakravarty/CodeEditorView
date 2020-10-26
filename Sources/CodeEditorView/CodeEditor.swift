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

  private var gutterView:          GutterView<UITextView>?
  private var codeStorageDelegate: CodeStorageDelegate?

  /// Designated initializer for code views with a gutter.
  ///
  init(frame: CGRect) {

    // Use a custom layout manager that is gutter-aware
    let codeLayoutManager = CodeLayoutManager(),
        textContainer     = NSTextContainer(),
        textStorage       = NSTextStorage()
    textStorage.addLayoutManager(codeLayoutManager)
    textContainer.layoutManager = codeLayoutManager
    codeLayoutManager.addTextContainer(textContainer)

    super.init(frame: frame, textContainer: textContainer)

    // Add a text storage delegate that maintains a line map
    self.codeStorageDelegate = CodeStorageDelegate()
    textStorage.delegate     = self.codeStorageDelegate

    // Add a gutter view
    let gutterWidth = (font?.pointSize ?? UIFont.systemFontSize) * 3,
        gutterView  = GutterView<UITextView>(frame: CGRect(x: 0,
                                                           y: 0,
                                                           width: gutterWidth,
                                                           height:  CGFloat .greatestFiniteMagnitude),
                                             textView: self)
    addSubview(gutterView)
    self.gutterView = gutterView
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
  @Binding var text: String

  public init(text: Binding<String>) {
    self._text = text
  }

  public func makeUIView(context: Context) -> UITextView {
    let textView = CodeViewWithGutter(frame: CGRect(x: 0, y: 0, width: 100, height: 40))

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

/// Customised layout manager for code layout.
///
class CodeLayoutManager: NSLayoutManager {

//  override func processEditing(for textStorage: NSTextStorage,
//                               edited editMask: NSTextStorage.EditActions,
//                               range newCharRange: NSRange,
//                               changeInLength delta: Int,
//                               invalidatedRange invalidatedCharRange: NSRange)
//  {
//    for textContainer in textContainers {
//      let textView = textContainer.textView
//    }
//  }
}


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
      CodeEditor(text: .constant("Hello World!"))
    }
  }
}
