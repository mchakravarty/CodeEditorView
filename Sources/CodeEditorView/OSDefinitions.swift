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

typealias OSFontDescriptor = UIFontDescriptor
typealias OSFont           = UIFont
public
typealias OSColor          = UIColor
typealias OSBezierPath     = UIBezierPath
typealias OSView           = UIView
typealias OSTextView       = UITextView
typealias OSHostingView    = UIHostingView

let labelColor = UIColor.label

typealias TextStorageEditActions = NSTextStorage.EditActions

extension UIFont {
  
  /// The constant adavance for a (horizontal) monospace font.
  ///
  var maximumHorizontalAdvancement: CGFloat {
    let ctFont = CTFontCreateWithFontDescriptor(fontDescriptor, pointSize, nil),
        xGlyph = [CTFontGetGlyphWithName(ctFont, "x" as NSString)]
    return CTFontGetAdvancesForGlyphs(ctFont, .horizontal, xGlyph, nil, 1)
  }
}

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

typealias OSFontDescriptor = NSFontDescriptor
typealias OSFont           = NSFont
public
typealias OSColor          = NSColor
typealias OSBezierPath     = NSBezierPath
typealias OSView           = NSView
typealias OSTextView       = NSTextView
typealias OSHostingView    = NSHostingView

let labelColor = NSColor.labelColor

typealias TextStorageEditActions = NSTextStorageEditActions

extension NSFont {

  /// The constant adavance for a (horizontal) monospace font.
  ///
  var maximumHorizontalAdvancement: CGFloat { self.maximumAdvancement.width }
}
extension NSColor {

  /// Create an AppKit colour from a SwiftUI colour if possible.
  ///
  convenience init?(color: Color) {
    guard let cgColor = color.cgColor else { return nil }
    self.init(cgColor: cgColor)
  }
}

#endif
