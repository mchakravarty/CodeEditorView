//
//  Message.swift
//  
//
//  Created by Manuel M T Chakravarty on 22/03/2021.
//
//  Messages are messages that can be displayed inline in a code view in short form and as a popup in long form.
//  They are bound to a particular primary location by way of line information, by may also include secondary locations
//  that contribute to the reported issue. A typical use case is diagnostic information.

import Foundation


/// A message that can be displayed in a code view.
///
public struct Message: Identifiable {

  /// The various category that a message can be in. The earlier in the enumeration, the higher priority in the sense
  /// that in the one-line view, the colour of the highest priority message will be used.
  ///
  public enum Category: Equatable, Comparable {

    /// A message related to live execution (e.g., debugger stepping position).
    ///
    case live

    /// An error — the program cannot be executed.
    ///
    case error

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

  /// The line at which the message is to be displayed.
  ///
  public let line: Int

  /// The columns whose characters the message are related to and which ought to be underlined.
  ///
  public let columns: Range<Int>

  /// Short version of the message (displayed inline and in the popup) — one line only.
  ///
  public let summary: String

  /// Optional long message (only displayed in the popup, but may extend over multiple lines).
  ///
  public let description: NSAttributedString?
}
