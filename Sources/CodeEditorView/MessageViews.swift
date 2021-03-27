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
      return (colour: Color.white, icon: Image(systemName: "info.circle.fill"))
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



// MARK: -
// MARK: Previews

let message1 = Message(category: .error, line: 1, column: 1, summary: "It's wrong!", description: nil),
    message2 = Message(category: .error, line: 1, column: 1, summary: "Need to fix this.", description: nil),
    message3 = Message(category: .warning, line: 1, column: 1, summary: "Looks dodgy.", description: nil)

struct MessageViews_Previews: PreviewProvider {
  static var previews: some View {

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 15, alignment: .center)

    MessageInlineView(messages: [message1], theme: Message.defaultTheme)
      .frame(width: 80, height: 25, alignment: .center)

    MessageInlineView(messages: [message1, message2], theme: Message.defaultTheme)
      .frame(width: 180, height: 15, alignment: .center)

    MessageInlineView(messages: [message1, message2, message3], theme: Message.defaultTheme)
      .frame(width: 180, height: 15, alignment: .center)

  }
}
