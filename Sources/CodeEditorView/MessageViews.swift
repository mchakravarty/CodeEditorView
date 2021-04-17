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

      HStack {

        Spacer()

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
          Divider()
            .background(Color.clear)

          // Topmost message of the highest priority category
          HStack {
            Text(messages.filter{ $0.category == categories[0] }.first?.summary ?? "")
              .padding([.leading, .trailing], 5)
          }
          .frame(height: height)
          .background(colour.opacity(0.5))

        }
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

private struct MessageBorder: ViewModifier {
  let cornerRadius: CGFloat

  @Environment(\.colorScheme) var colourScheme: ColorScheme

  func body(content: Content) -> some View {

    let shadowColour = colourScheme == .dark ? Color(.sRGBLinear, white: 0, opacity: 0.66)
                                             : Color(.sRGBLinear, white: 0, opacity: 0.33)

    if colourScheme == .dark {
      return AnyView(content
                      .shadow(color: shadowColour, radius: 2, y: 2)
                      .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1))
                      .padding(1)
                      .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.black, lineWidth: 1)))
    } else {
      return AnyView(content
                      .shadow(color: shadowColour, radius: 1, y: 1)
                      .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)))
    }
  }
}

extension View {

  fileprivate func messageBorder(cornerRadius: CGFloat) -> some View {
    modifier(MessageBorder(cornerRadius: cornerRadius))
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

  let cornerRadius: CGFloat = 10

  @Environment(\.colorScheme) var colourScheme: ColorScheme
  @Environment(\.popupWidth)  var popupWidth:   CGFloat?

  var body: some View {

    let backgroundColour = colourScheme == .dark ? Color.black : Color.white

    HStack(spacing: 0) {

      // Category icon
      ZStack (alignment: .top) {
        theme(category).colour.opacity(0.5)
        Text("XX")       // We want the icon to have the height of text
          .hidden()
          .overlay( theme(category).icon.frame(alignment: .center) )
          .padding([.leading, .trailing], 5)
          .padding([.top, .bottom], 3)
      }.fixedSize(horizontal: true, vertical: false)

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
    .messageBorder(cornerRadius: cornerRadius)
  }
}

struct MessagePopupView: View {
  let messages: [Message]
  let theme:    Message.Theme

  /// The width of the text in the message category with the widest text.
  ///
  @State private var popupWidth: CGFloat?  = nil

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
// MARK: Combined view

/// SwiftUI view that displays an array of messages that lie on the same line. It supports switching between an inline
/// format and a full popup format by clicking/tapping on the message.
///
struct MessageView: View {
  struct Geometry {

    /// The maximum width that the inline view may use.
    ///
    let lineWidth:   CGFloat

    /// The height of the inline view
    ///
    let lineHeight:  CGFloat

    /// The maximum width that the popup view may use.
    ///
    let popupWidth:  CGFloat

    /// The distance from the top where the popup view must be placed.
    ///
    let popupOffset: CGFloat
  }

  let messages:    [Message]        // The array of messages that are displayed by this view
  let theme:       Message.Theme    // The message display theme to use
  let geometry:    Geometry

  @Binding var unfolded: Bool       // False => inline view; true => popup view

  var body: some View {
    Group {
      if unfolded {

        MessagePopupView(messages: messages, theme: theme)
          .frame(maxWidth: geometry.popupWidth)
          .offset(x: -20, y: geometry.popupOffset)
          .onTapGesture { unfolded.toggle() }

      } else {

        MessageInlineView(messages: messages, theme: theme)
          .frame(minWidth: MessageView.minimumInlineWidth, maxWidth: geometry.lineWidth, maxHeight: geometry.lineHeight)
          .transition(.opacity)
          .onTapGesture { unfolded.toggle() }

      }
    }
  }
}

extension MessageView {

  // FIXME: This should maybe depend on the font size and may need to be configurable.
  static let minimumInlineWidth = CGFloat(60)
}


// MARK: -
// MARK: Stateful combined view

/// SwiftUI view that displays an array of messages that lie on the same line. It supports switching between an inline
/// and popup view by tapping.
///
struct StatefulMessageView: View {
  let messages:    [Message]              // The array of messages that are displayed by this view
  let theme:       Message.Theme          // The message display theme to use
  let geometry:    MessageView.Geometry   // The geometry constrains for the view
  let unfolded:    Bool                   // `true` iff the view should first appear in the popup flavour

  @State private var toggeld: Bool = false

  var body: some View {
    MessageView(messages: messages,
                theme: theme,
                geometry: geometry,
                unfolded: Binding(get: { unfolded != toggeld },
                                  set: { toggeld = $0 != unfolded }))
  }
}

#if os(iOS)

//extension MessageInlineView {
//
//  /// Wrap the message view into a hosting view.
//  ///
//  var hostedView: UIHostingView<MessageInlineView> { UIHostingView(rootView: self) }   // FIXME: there is no `UIHostingView`!!!
//}

#elseif os(macOS)

extension StatefulMessageView {

  class HostingView: NSView {
    private var hostingView: NSHostingView<StatefulMessageView>?

    private let messages: [Message]
    private let theme   : Message.Theme

    var geometry: MessageView.Geometry {
      didSet { reconfigure() }
    }
    var unfolded: Bool {
      didSet { reconfigure() }
    }

    private var unfoldedBinding: Binding<Bool>?

    init(messages: [Message], theme: @escaping Message.Theme, geometry: MessageView.Geometry)
    {
      self.messages = messages
      self.theme    = theme
      self.geometry = geometry
      self.unfolded = false
      super.init(frame: NSRect.zero)

      self.hostingView = NSHostingView(rootView: StatefulMessageView(messages: messages,
                                                                     theme: theme,
                                                                     geometry: geometry,
                                                                     unfolded: unfolded))
      hostingView?.autoresizingMask = [.width, .height]
      if let view = hostingView { addSubview(view) }
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func reconfigure() {
      self.hostingView?.rootView = StatefulMessageView(messages: messages,
                                                       theme: theme,
                                                       geometry: geometry,
                                                       unfolded: unfolded)
    }
  }
}

#endif



// MARK: -
// MARK: Previews

let message1 = Message(category: .error, line: 1, columns: 1..<2, summary: "It's wrong!", description: nil),
    message2 = Message(category: .error, line: 1, columns: 1..<2, summary: "Need to fix this.", description: nil),
    message3 = Message(category: .warning, line: 1, columns: 1..<2, summary: "Looks dodgy.",
                       description: NSAttributedString(string: "This doesn't seem right and also totally unclear " +
                                                        "what it is supposed to do.")),
    message4 = Message(category: .live, line: 1, columns: 1..<2, summary: "Thread 1", description: nil),
    message5 = Message(category: .informational, line: 1, columns: 1..<2, summary: "Cool stuff!", description: nil)

struct MessageViewPreview: View {
  let messages:    [Message]
  let theme:       Message.Theme
  let geometry:    MessageView.Geometry

  @State private var unfolded: Bool = false

  var body: some View {
    MessageView(messages: messages,
                theme: theme,
                geometry: geometry,
                unfolded: $unfolded)
  }
}

struct MessageViews_Previews: PreviewProvider {

  static var previews: some View {

    // Inline view

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 15, alignment: .center)
      .preferredColorScheme(.dark)

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 25, alignment: .center)
      .preferredColorScheme(.dark)

    VStack{

      MessageInlineView(messages: [message1, message2], theme: Message.defaultTheme)
        .frame(width: 180, height: 15, alignment: .center)
        .preferredColorScheme(.dark)

      MessageInlineView(messages: [message1, message2, message3], theme: Message.defaultTheme)
        .frame(width: 180, height: 15, alignment: .center)
        .preferredColorScheme(.dark)

    }

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

    // Combined view

    ZStack(alignment: .topTrailing) {

      Rectangle()
        .foregroundColor(Color.red.opacity(0.1))
        .frame(height: 30)
      HStack { Text("main = putStrLn \"Hello World!\""); Spacer() }
      StatefulMessageView(messages: [message1, message5, message2, message4, message3],
                          theme: Message.defaultTheme,
                          geometry: MessageView.Geometry(lineWidth: 150,
                                                         lineHeight: 15,
                                                         popupWidth: 300,
                                                         popupOffset: 30),
                          unfolded: false)
    }
    .frame(width: 400, height: 300, alignment: .topTrailing)
//    .preferredColorScheme(.light)

  }
}
