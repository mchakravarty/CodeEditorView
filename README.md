# SwiftUI code editor view for iOS, visionOS, and macOS

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmchakravarty%2FCodeEditorView%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mchakravarty/CodeEditorView)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmchakravarty%2FCodeEditorView%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mchakravarty/CodeEditorView)

The package `CodeEditorView` provides a SwiftUI view implementing a code editor for iOS, visionOS, and macOS whose visual style is inspired by Xcode and that is based on TextKit 2. The currently supported functionality includes syntax highlighting with configurable themes, inline message reporting (warnings, errors, etc), bracket matching, matching bracket insertion, current line highlighting, common code editing operations, and a minimap.

On macOS, `CodeEditorView` also supports (1) displaying information about identifiers (such as type information and documentation provided in Markdown) as well as (2) code completion. This support is independent of how the underlying information is computed — a common choice is to use a language server based on the Language Server Protocol (LSP). This functionality will eventually also be supported on iOS.

## Screenshots of the demo app

This is the default dark theme on macOS. Like in Xcode, messages have got an inline view on the right-hand side of the screen, which pops up into a larger overlay to display more information. The minimap on the right provides an outline of the edited text.

<img src="app-demo-images/macOS-dark-example.png">

The following is the default light theme on iOS. 

<img src="app-demo-images/iOS-light-example.png">


## How to use it

Typical usage of the view is as follows.

```swift
import SwiftUI
import CodeEditorView
import LanguageSupport

struct ContentView: View {
  @State private var text:     String                    = "My awesome code..."
  @State private var position: CodeEditor.Position       = CodeEditor.Position()
  @State private var messages: Set<TextLocated<Message>> = Set()

  @Environment(\.colorScheme) private var colorScheme: ColorScheme

  var body: some View {
    CodeEditor(text: $text, position: $position, messages: $messages, language: .swift())
      .environment(\.codeEditorTheme,
                   colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
  }
}
```


## Demo app

To see the `CodeEditorView` in action, have a look at the repo with a [cross-platform demo app](https://github.com/mchakravarty/CodeEditorDemo).


## Documentation

For more information, see the [package documentation](Documentation/Overview.md).


## Status

I consider this package still to be of pre-release quality, but at this stage, it is mostly a set of known bugs, which prevents it from being a 1.0.

## License

Copyright [2021..2025] Manuel M. T. Chakravarty. 

Distributed under the Apache-2.0 license — see the [license file](LICENSE) for details.
