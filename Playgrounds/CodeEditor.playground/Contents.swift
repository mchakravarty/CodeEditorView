import SwiftUI
import CodeEditorView

struct CountingEditor: View {
  @State private var text = "Goede morgen!"

  var body: some View {
    VStack {
//      TextEditor(text: $text)
      CodeEditor(text: $text)
        .frame(width: 600, height: 800, alignment: .leading)
      HStack {
        Spacer()
        Text("\(text.count) letters")
      }
    }
  }
}

let codeEditor = CountingEditor()

import PlaygroundSupport
PlaygroundPage.current.setLiveView(codeEditor)
