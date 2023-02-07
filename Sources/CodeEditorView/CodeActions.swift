//
//  CodeActions.swift
//  
//
//  Created by Manuel M T Chakravarty on 31/01/2023.
//

import SwiftUI
import os


private let logger = Logger(subsystem: "co.applicative.notebook", category: "CodeActions")


#if os(iOS)

// MARK: -
// MARK: UIKit version


#elseif os(macOS)

// MARK: -
// MARK: AppKit version

// MARK: Code info support

/// Popover used to display the result of an info code query.
///
final class InfoPopover: NSPopover {

  /// Create an info popover with the given view displaying the code info.
  ///
  /// - Parameter view: the view displaying the queried code information.
  ///
  init(displaying view: any View) {
    super.init()
    contentViewController = NSHostingController(rootView: AnyView(view))
    behavior              = .transient
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension CodeView {

  /// Retain and display the given info popover.
  ///
  /// - Parameters:
  ///   - infoPopover: The new info popover to be displayed.
  ///   - range: The range of characters that the popover ought to refer to.
  ///
  @MainActor
  func show(infoPopover: InfoPopover, for range: NSRange) {

    // If there is already a popover, close it first.
    self.infoPopover?.close()

    self.infoPopover = infoPopover

    let screenRect  = firstRect(forCharacterRange: range, actualRange: nil),
        windowRect  = window!.convertFromScreen(screenRect)

    infoPopover.show(relativeTo: convert(windowRect, from: nil), of: self, preferredEdge: .maxY)
  }

  func infoAction() {
    guard let languageService = optLanguageService else { return }

    let range = selectedRange()
    Task {
      do {
        if let info = try await languageService.info(at: range.location) {

          show(infoPopover: InfoPopover(displaying: info.view), for: info.anchor ?? range)

        }
      } catch let error { logger.error("Info action failed: \(error.localizedDescription)") }
    }
  }
}

#endif
