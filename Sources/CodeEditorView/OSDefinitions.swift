//
//  OSDefinitions.swift
//  
//
//  Created by Manuel M T Chakravarty on 04/05/2021.
//
//  A set of aliases and the like to smooth ove some superficial macOS/iOS differences.

import SwiftUI

#if os(iOS)

import UIKit

typealias OSFont       = UIFont
typealias OSColor      = UIColor
typealias OSBezierPath = UIBezierPath

let labelColor = UIColor.label

typealias TextStorageEditActions = NSTextStorage.EditActions

extension UIColor {

  /// Create a UIKit colour from a SwiftUI colour if possible.
  ///
  convenience init?(color: Color) {
    guard let cgColor = color.cgColor else { return nil }
    self.init(cgColor: cgColor)
  }
}

#elseif os(macOS)

import AppKit

typealias OSFont       = NSFont
typealias OSColor      = NSColor
typealias OSBezierPath = NSBezierPath

let labelColor = NSColor.labelColor

typealias TextStorageEditActions = NSTextStorageEditActions

extension NSColor {

  /// Create an AppKit colour from a SwiftUI colour if possible.
  ///
  convenience init?(color: Color) {
    guard let cgColor = color.cgColor else { return nil }
    self.init(cgColor: cgColor)
  }
}

#endif
