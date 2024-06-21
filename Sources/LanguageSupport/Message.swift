//
//  Message.swift
//  
//
//  Created by Manuel M T Chakravarty on 22/03/2021.
//
//  Messages are messages that can be displayed inline in a code view in short form and as a popup in long form.
//  They are bound to a particular primary location by way of line information, but may also include secondary locations
//  that contribute to the reported issue. A typical use case is diagnostic information.

import Foundation


/// A message that can be displayed in a code view.
///
public struct Message {

  /// The various category that a message can be in. The earlier in the enumeration, the higher priority in the sense
  /// that in the one-line view, the colour of the highest priority message will be used.
  ///
  public enum Category: Equatable, Comparable, CaseIterable {

    /// A message related to live execution (e.g., debugger stepping position).
    ///
    case live

    /// An error — the program cannot be executed.
    ///
    case error

    /// A hole — indicating a gap in the code that still needs to be filled in.
    ///
    case hole

    /// A warning — indicating a possible problem that doesn't prevent execution.
    ///
    case warning

    /// A message without any direct impact on the validity of the program.
    ///
    case informational
  }

  /// Unique identity of the message.
  ///
  public let id: UUID = UUID()

  /// The message category
  ///
  public let category: Category

  /// The number of characters that the message is related to and which ought to be underlined.
  ///
  public let length: Int
  
  /// Short version of the message (displayed inline and in the popup) — one line only.
  ///
  public let summary: String

  /// Optional long message (only displayed in the popup, but may extend over multiple lines).
  ///
  public var description: NSAttributedString?

  /// The number of lines, beyond the line on which the message is located, that are to be highlighted (as they are
  /// within the scope of the message).
  ///
  public let telescope: Int?

  public init(category: Message.Category, 
              length: Int,
              summary: String,
              description: NSAttributedString?,
              telescope: Int? = nil)
  {
    self.category    = category
    self.length      = length
    self.summary     = summary
    self.description = description
    self.telescope   = telescope
  }
}

extension Message: Equatable {
  public static func ==(lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
}

extension Message: Hashable {
  public func hash(into hasher: inout Hasher) {
    id.hash(into: &hasher)
  }
}

/// Order and sort an array of messages by categories.
///
public func messagesByCategory(_ messages: [Message]) -> [(key: Message.Category, value: [Message])] {
  Array(Dictionary(grouping: messages){ $0.category }).sorted{ $0.key < $1.key }
}
