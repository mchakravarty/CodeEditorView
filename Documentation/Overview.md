#  Documentation of the SwiftUI view `CodeEditor`


`CodeEditor` is a SwiftUI view implementing a general-purpose code editor. It works on macOS (from 12.0) and on iOS (from 15.0). As far as prossible, it tries to provide the same functionality on macOS and iOS, but this is not always possible because the iOS version of TextKit does miss some of the APIs exposed on macOS, such as the type setter API. The currently most significant omission on iOS is the minimap.


## The main view

Typical usage of the `CodeEditor` view is as roughly follows.

```swift
struct ContentView: View {
  @State private var text:     String                    = "My awesome code..."
  @State private var messages: Set<TextLocated<Message>> = Set ()

  @Environment(\.colorScheme) private var colorScheme: ColorScheme

  @SceneStorage("editPosition") private var editPosition: CodeEditor.Position = CodeEditor.Position()

  var body: some View {
    CodeEditor(text: $text, position: $editPosition, messages: $messages, language: .swift)
      .environment(\.codeEditorTheme,
                   colorScheme == .dark ? Theme.defaultDark : Theme.defaultLight)
  }
}
```

The view receives here four arguments:

1. a binding to a `String` that contains the edited text,
2. a binding to the current edit position (i.e., selection and scroll position),
3. a binding to a set of the currently reported `Messages` pertaining to individual lines of the edited text, and
4. a language configuration that controls language-specific editing suppport such as syntax highlighting.

The binding to the edit position and the language configuration are optional. Moreover, there is a fifth optional argument that we are not using here, namely, the layout used for the code editor view.

Moreover, a `CodeEditor` honours the `codeEditorTheme` environment variable, which determines the theme to use for syntax highlighting.

To see a complete working example, see the [CodeEditorView demo app](https://github.com/mchakravarty/CodeEditorDemo).


## Messages

Messages are notifications that can be reported on a line by line basis. They can be created using the following initialiser:

```swift
init(category: Message.Category, length: Int, summary: String, description: NSAttributedString?)
```

The message category determines the type of message, the length are the number of characters that ought to be marked (but this is not implemented yet). The summary is a short form of the message used inline on the right hand side of the code view, whereas the description an optional more detailed version specifies. For example, a summary could be that there is a type error and the description could explain the nature of the type error in more detail.

Initially, the summary is displayed inline. Once the user clicks or taps on the summary, the detailed description is shown in a popup. Clicking or tapping on the detailed description collapses it again. 

New messages are reported by adding them to the set. Similarily, they can be removed the message set to retract them. The code editor will also automatically remove any messages on lines that have been edited.

More details about messages support are in [Messages](Messages.md).

### Locations

Messages are *located* by way of a generic wrapper:

```swift
struct TextLocated<Entity> {
  let location: TextLocation
  let entity:   Entity
}

struct TextLocation {
  let zeroBasedLine:   Int   // starts from line 0
  let zeroBasedColumn: Int   // starts from column 0
}
```

`TextLocation.line` determines the line at which a message is going to be displayed. During editing, messages stick to the lines at which they are reported. For example, if the user adds additional lines before the line at which a message got reported, the message will stick to its original line moving down with it. Note however, that the `Located` wrapper does not get updated in that process, it always specifices the initial line number at the time of reporting. Messages conform to `Identifable` to enable distinguishing between them independently of the reporting location.

### Categories

Currently, four categories are supported (in order of priority): `.live`, `.error`, `.warning`, and `.informational`. The message category is used to selected a message colour out of a message theme. That colour is used as a background when rendering the message and also to highlight the line at which a message gets reported. If multiple messages are reported on the same line, the colour of the inline version (and line highlight) is determined by the message of the highest priority.

Currently, the message theme is hardcoded, but it will become configurable in the future. (Details are still to be determined.)


## Language configurations

`LanguageConfiguration`s determine syntaxtic properties, which are used for syntax highlight, bracket matching, and similar syntax-dependent functionality. More precisely, language confugurations provide information that enables the code editor to tokenise the edited code in real time using a custom tokeniser based on `NSRegularExpression`. Tokenisers are finite-state machines (FSM) whose state transitions dependent on the matched regular expressions and who use different regular expressions depending on the FSM state. This enables us to tokenise differently depending on whether we are, for example, in a nested comment or in plain code. The tokeniser is a generic extension of `NSMutableAttributedString` (contained in the file `MutableAttributedString.swift`) and may be of independent interest.

A language configuration specifies language-dependent tokenisation rules in the form of a struct that determines what comment delimiters to use, regular expressions for string and numeric literals as well as for identifiers. The configuration options are currently still fairly limited. Example configurations for Swift and Haskell are included. Configurations for other languages can be defined in a similar manner. 


## Syntax highlighting

Syntax highlighting is currently completely static and only based on token classification. Longer term, the aim is to have basic highlighting on the basis of token classification (as now) in combination with semantic highlighting on the basis of code analysis as performed, for example, by SourceKit.

The tokeniser depending on the language configuration uses two new `NSAttributedString.Key`s to mark comments with `.comment` and general tokens with `.token`. The token attribute value is of type `LanguageConfiguration.Token` and gets continously updated as the text edited. For optimal performance, we use on-the-fly custom attribute translation (in a custom subclass of the `NSTextStorage` class cluster, called `CodeStorage`). Moreover, syntax highlighting only varies the foreground colour of tokens to keep type setting independent of highlighting.

NB: Temporary attributes are no option, because they are no supported by `NSLayoutManager` on iOS.

### Themes

The `Theme` struct determines a font name and a font size together with colours for the various recognised types of tokens and for general colour elements, such as the cursor colour, selection colour, and so on. On iOS, TextKit doesn't allow us to customise the cursor and selection colour idenpendently. Hence, we derive an appropriate tint colour from the theme's selection colour.
