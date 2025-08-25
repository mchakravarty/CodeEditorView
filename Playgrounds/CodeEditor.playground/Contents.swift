import SwiftUI
import CodeEditorView
import LanguageSupport


struct Editor: View {
  @State private var text = "main = print 42"
  @State private var position: CodeEditor.Position       = CodeEditor.Position()
  @State private var messages: Set<TextLocated<Message>> = Set()

  var body: some View {
      CodeEditor(text: $text, position: $position, messages: $messages, language: .swift())
  }
}

let codeEditor = Editor()

import PlaygroundSupport
PlaygroundPage.current.setLiveView(codeEditor)
