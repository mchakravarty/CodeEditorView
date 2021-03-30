//
//  MessageViews.swift
//  
//
//  Created by Manuel M T Chakravarty on 23/03/2021.
//
//  Defines the visuals that present messages, both inline and as popovers.

import SwiftUI


// MARK: -
// MARK: Message category themes

extension Message {

  /// Defines the colours and icons that identify each of the various message categories.
  ///
  typealias Theme = (Message.Category) -> (colour: Color, icon: Image)

  /// The default category theme
  ///
  static func defaultTheme(for category: Message.Category) -> (colour: Color, icon: Image) {
    switch category {
    case .live:
      return (colour: Color.green, icon: Image(systemName: "line.horizontal.3"))
    case .error:
      return (colour: Color.red, icon: Image(systemName: "xmark.circle.fill"))
    case .warning:
      return (colour: Color.yellow, icon: Image(systemName: "exclamationmark.triangle.fill"))
    case .informational:
      return (colour: Color.gray, icon: Image(systemName: "info.circle.fill"))
    }
  }
}


// MARK: -
// MARK: Inline view

/// A view that summarises the message for a line, such that it can be displayed on the right hand side of the line.
/// The view uses the entire height offered.
///
/// NB: The array of messages may not be empty.
///
struct MessageInlineView: View {
  let messages: [Message]
  let theme:    Message.Theme

  var body: some View {

    let categories = Dictionary(grouping: messages){ $0.category }.keys.sorted()

    GeometryReader { geometryProxy in

      let height = geometryProxy.size.height

      HStack(alignment: .center, spacing: 0) {
        let colour = theme(categories[0]).colour

        // Category summary
        HStack(alignment: .center, spacing: 0) {

          // Overall message count
          let count = messages.count
          if count > 1 {
            Text("\(count)")
              .padding([.leading, .trailing], 3)
          }

          // All category icons
          HStack(alignment: .center, spacing: 0) {
            ForEach(0..<categories.count){ i in
              HStack(alignment: .center, spacing: 0) {
                theme(categories[i]).icon
                  .padding([.leading, .trailing], 2)
              }
            }
          }
          .padding([.leading, .trailing], 2)

        }
        .frame(height: height)
        .background(colour.opacity(0.5))
        .roundedCornersOnTheLeft(cornerRadius: 5)

        // Transparent narrow separator
        Spacer(minLength: 1)
          .background(Color.clear)

        // Topmost message of the highest priority category
        HStack {
          Text(messages.filter{ $0.category == categories[0] }.first?.summary ?? "")
            .padding([.leading, .trailing], 5)
          Spacer(minLength: 0)
        }
        .frame(height: height)
        .background(colour.opacity(0.5))

      }
    }
  }
}


// MARK: -
// MARK: Popup view


/// Key to track the width for a set of message popup views.
///
private struct PopupWidth: PreferenceKey, EnvironmentKey {

  static let defaultValue: CGFloat? = nil
  static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
    if let nv = nextValue() { value = value.flatMap{ max(nv, $0) } ?? nv }
  }
}

/// Accessor for the environment value identified by the key.
///
extension EnvironmentValues {

  var popupWidth: CGFloat? {
    get { self[PopupWidth.self] }
    set { self[PopupWidth.self] = newValue }
  }
}

/// A view that display all the information of a list of messages.
///
/// NB: The array of messages may not be empty.
///
fileprivate struct MessagePopupCategoryView: View {
  let category: Message.Category
  let messages: [Message]
  let theme:    Message.Theme

  let cornerRadius: CGFloat = 10,
      iconWidth   : CGFloat = 20

  @Environment(\.colorScheme) var colourScheme: ColorScheme
  @Environment(\.popupWidth)  var popupWidth:   CGFloat?

  var body: some View {

    let backgroundColour = colourScheme == .dark ? Color.black : Color.white,
        shadowColour     = colourScheme == .dark ? Color(.sRGBLinear, white: 1, opacity: 0.33)
                                                 : Color(.sRGBLinear, white: 0, opacity: 0.33)

    HStack(spacing: 0) {

      // Category icon
      VStack {
        Text("XX")       // We want the icon to have the height of text
          .hidden()
          .overlay( theme(category).icon.frame(alignment: .center) )
        Spacer(minLength: 0)
      }
      .padding([.leading, .trailing], 5)
      .padding([.top, .bottom], 3)
      .background(theme(category).colour.opacity(0.5))


      // Vertical stack of message
      VStack(alignment: .leading, spacing: 6) {
        ForEach(0..<messages.count) { i in
          Text(messages[i].summary)
          if let description = messages[i].description { Text(description.string) }
        }
      }
      .padding([.leading, .trailing], 5)
      .padding([.top, .bottom], 3)
      .frame(maxWidth: popupWidth, alignment: .leading)       // Constrain width if `popupWidth` is not `nil`
      .background(theme(category).colour.opacity(0.3))
      .background(GeometryReader { proxy in                   // Propagate current width up the view tree
        Color.clear.preference(key: PopupWidth.self, value: proxy.size.width)
      })


    }
    .background(backgroundColour)
    .cornerRadius(cornerRadius)
    .fixedSize(horizontal: false, vertical: true)           // horizontal must wrap and vertical extend
    .overlay(RoundedRectangle(cornerRadius: cornerRadius)
              .stroke(Color.gray, lineWidth: 1))
    .shadow(color: shadowColour, radius: 1)
  }
}

struct MessagePopupView: View {
  let messages: [Message]
  let theme:    Message.Theme

  /// The width of the text in the message category with the widest text.
  ///
  @State var popupWidth: CGFloat?  = nil

  var body: some View {

    let categories = Array(Dictionary(grouping: messages){ $0.category }).sorted{ $0.key < $1.key }

    VStack(spacing: 4) {
      ForEach(0..<categories.count) { i in
        MessagePopupCategoryView(category: categories[i].0, messages: categories[i].1, theme: theme)
      }
    }
    .background(Color.clear)
    .onPreferenceChange(PopupWidth.self) { self.popupWidth = $0 }   // Update the state variable with current width...
    .environment(\.popupWidth, popupWidth)                          // ...and propagate that value down the view tree.
  }
}


// MARK: -
// MARK: Previews

let message1 = Message(category: .error, line: 1, column: 1, summary: "It's wrong!", description: nil),
    message2 = Message(category: .error, line: 1, column: 1, summary: "Need to fix this.", description: nil),
    message3 = Message(category: .warning, line: 1, column: 1, summary: "Looks dodgy.",
                       description: NSAttributedString(string: "This doesn't seem right and also totally unclear " +
                                                        "what it is supposed to do.")),
    message4 = Message(category: .live, line: 1, column: 1, summary: "Thread 1", description: nil),
    message5 = Message(category: .informational, line: 1, column: 1, summary: "Cool stuff!", description: nil)

struct MessageViews_Previews: PreviewProvider {
  static var previews: some View {

    // Inline view

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 15, alignment: .center)
      .preferredColorScheme(.dark)

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 25, alignment: .center)
      .preferredColorScheme(.dark)

    MessageInlineView(messages: [message1, message2], theme: Message.defaultTheme)
      .frame(width: 180, height: 15, alignment: .center)
      .preferredColorScheme(.dark)

    MessageInlineView(messages: [message1, message2, message3], theme: Message.defaultTheme)
      .frame(width: 180, height: 15, alignment: .center)
      .preferredColorScheme(.dark)

    MessageInlineView(messages: [message1, message2, message3], theme: Message.defaultTheme)
      .frame(width: 180, height: 15, alignment: .center)
      .preferredColorScheme(.light)

    // Popup view

    MessagePopupView(messages: [message1], theme: Message.defaultTheme)
      .font(.system(size: 32))
      .frame(maxWidth: 320, minHeight: 15)
      .preferredColorScheme(.dark)

    MessagePopupView(messages: [message1, message4], theme: Message.defaultTheme)
      .frame(maxWidth: 320, minHeight: 15)
      .preferredColorScheme(.dark)

    MessagePopupView(messages: [message1, message2, message3], theme: Message.defaultTheme)
      .frame(maxWidth: 320, minHeight: 15)
      .preferredColorScheme(.dark)

    MessagePopupView(messages: [message1, message5, message2, message4, message3], theme: Message.defaultTheme)
      .frame(maxWidth: 320, minHeight: 15)
      .preferredColorScheme(.dark)

    MessagePopupView(messages: [message1, message5, message2, message4, message3], theme: Message.defaultTheme)
      .frame(maxWidth: 320, minHeight: 15)
      .preferredColorScheme(.light)

  }
}
