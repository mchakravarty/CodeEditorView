import SwiftUI
import CodeEditorView


let regexp  = try! NSRegularExpression(pattern: "--|\\{-|-\\}", options: []),
    string  = "a -- b\n -- {- x -}",
    matches = regexp.matches(in: string, options: [], range: NSRange(location: 0,
                                                                     length: string.count))
matches.count
matches[0].range
matches[0].numberOfRanges
matches[1].range
matches[2].range
matches[3].range
let results = matches.map{ (string as NSString).substring(with: $0.range) }
results

struct Editor: View {
  @State private var text = "main = print 42"

  var body: some View {
    CodeEditor(text: $text)
  }
}

let codeEditor = Editor()

import PlaygroundSupport
PlaygroundPage.current.setLiveView(codeEditor)
