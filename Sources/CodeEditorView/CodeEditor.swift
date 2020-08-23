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

  public init() { }

  public func makeUIView(context: Context) -> UITextView {
    return UITextView()
  }

  public func updateUIView(_ uiView: UITextView, context: Context) {
  }
}

#elseif os(macOS)

// MARK: -
// MARK: AppKit version

public struct CodeEditor: NSViewRepresentable {

  public init() { }

  public func makeNSView(context: Context) -> NSTextView {
    return NSTextView()
  }

  public func updateNSView(_ nsView: NSTextView, context: Context) {
  }
}

#endif

struct CodeEditor_Previews: PreviewProvider {
  static var previews: some View {
    VStack{
    CodeEditor()
    TextEditor(text: .constant("bla"))
    }
  }
}
