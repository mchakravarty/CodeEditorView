# SwiftUI code editor view for iOS and macOS

The `CodeEditorView` Swift package provides a SwiftUI view implementing a rich code editor for iOS and macOS whose visual style is inspired by Xcode. The currently supported functionality includes syntax highlighting with configurable themes, inline message (warnings, errors, etc) reporting, bracket matching, matching bracket insertion, and a minimap (only on macOS).

## How to use it

Typical ussage of the view is as follows.

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

To see the `CodeEditorView` in action, have a look at the separate [cross-platform demo app](https://github.com/mchakravarty/CodeEditorDemo).

## License

Copyright 2021 Manuel M. T. Chakravarty. 

Distributed under the Apache-2.0 license — see the [license file](LICENSE) for details.
