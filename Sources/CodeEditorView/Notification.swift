//
//  Notification.swift
//  
//
//  Created by Manuel M T Chakravarty on 22/03/2021.
//
//  Notifications are messages that can be displayed inline in a code view in short form and as a popup in long form.
//  They are bound to a particular primary location by way of line information, by may also include secondary locations
//  that contribute to the reported issue. A typical use case is diagnostic information.

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


/// A notification that can be displayed in a code view.
///
public struct Notification: Identifiable {

  public struct Category: Equatable, RawRepresentable {
    public typealias RawValue = String

    public var rawValue: RawValue

    #if os(iOS)

    /// Display colour of the notification.
    ///
    var colour: UIColor

    /// Icon image identifying the notification category.
    ///
    var icon: UIImage

    public init?(rawValue: String) {
      self.rawValue = rawValue
      self.colour   = UIColor.systemRed
      self.icon     = UIImage(systemName: "exclamationmark.circle.fill") ?? NSImage()
    }

    public init?(rawValue: String, colour: UIColor, icon: UIImage) {
      self.init(rawValue: rawValue)
      self.colour = colour
      self.icon   = icon
    }

    #elseif os(macOS)

    /// Display colour of the notification.
    ///
    var colour: NSColor

    /// Icon image identifying the notification category.
    ///
    var icon: NSImage

    public init?(rawValue: String) {
      self.rawValue = rawValue
      self.colour   = NSColor.systemRed
      self.icon     = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil) ?? NSImage()
    }

    public init?(rawValue: String, colour: NSColor, icon: NSImage) {
      self.init(rawValue: rawValue)
      self.colour = colour
      self.icon   = icon
    }

    #endif
  }

  /// Unique identity of the notification.
  ///
  public let id: UUID

  /// The line at which the notification is to be displayed.
  ///
  public let line: Int

  /// Short version of the notification (displayed inline and in the popup) — one line only.
  ///
  public let summary: String

  /// Optional long message (only displayed in the popup, but may extend over multiple lines).
  ///
  public let description: NSAttributedString?
}

extension Notification.Category {

  #if os(iOS)

  public static let error = Notification.Category(rawValue: "error",
                                                  colour: UIColor.systemRed,
                                                  icon: UIImage(systemName: "exclamationmark.circle.fill") ?? NSImage())

  #elseif os(macOS)

  public static let error = Notification.Category(rawValue: "error",
                                                  colour: NSColor.systemRed,
                                                  icon: NSImage(systemSymbolName: "exclamationmark.circle.fill",
                                                                accessibilityDescription: nil) ?? NSImage())

  #endif
}
