# SwiftUI code editor view for iOS and macOS

The `CodeEditorView` Swift package provides a SwiftUI view implementing a rich code editor for iOS and macOS whose visual style is inspired by Xcode. The currently supported functionality includes syntax highlighting with configurable themes, inline message (warnings, errors, etc) reporting, bracket matching, matching bracket insertion, current line highlighting, and a minimap (only on macOS).

## Screenshots of the demo app

This is the default dark theme on macOS. Like in Xcode, messages have got an inline view on the right hand side of the screen, which pops up into a larger overlay to display more information. The minimap on the right provides an outline of the edited text.

<img src="app-demo-images/macOS-dark-example.png">

The following is the default light theme on iOS. Both line highlighting and the minimap are currently not supported on iOS due to limitations in the iOS version of TextKit. Instead of the line highlight, both the current line (or the current selection range) and lines with messages are indicated with differently coloured line numbers in the gutter.

<img src="app-demo-images/iOS-light-example.png">

## How to use it

Typical usage of the view is as follows.

```swift
struct ContentView: View {
  @State private var text:     String                = "My awesome code..."
  @State private var messages: Set<Located<Message>> = Set ()

  @Environment(\.colorScheme) private var colorScheme: ColorScheme

  var body: some View {
    CodeEditor(text: $text, messages: $messages, language: .swift)
      .environment(\.codeEditorTheme,
                   colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
  }
}
```

## Demo app

To see the `CodeEditorView` in action, have a look at the repo with a [cross-platform demo app](https://github.com/mchakravarty/CodeEditorDemo).

## License

Copyright 2021 Manuel M. T. Chakravarty. 

Distributed under the Apache-2.0 license — see the [license file](LICENSE) for details.
