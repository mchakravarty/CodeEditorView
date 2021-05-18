import SwiftUI
import CodeEditorView


struct Editor: View {
  @State private var text = "main = print 42"

  var body: some View {
    CodeEditor(text: $text)
  }
}

let codeEditor = Editor()

import PlaygroundSupport
PlaygroundPage.current.setLiveView(codeEditor)
