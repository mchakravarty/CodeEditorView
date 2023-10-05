//
//  TextContentStorageExtras.swift
//
//
//  Created by Manuel M T Chakravarty on 02/10/2023.
//

import SwiftUI


extension NSTextContentStorage {

  /// Convert a text location to a character location within this text content storage.
  ///
  /// - Parameter textLocation: The text location to convert.
  /// - Returns: The corresponding character position in the underlying text storage.
  ///
  func location(for textLocation: NSTextLocation) -> Int {
    offset(from: documentRange.location, to: textLocation)
  }
  
  /// Convert a character location into a text location within this text content storage.
  ///
  /// - Parameter location: The character location to convert.
  /// - Returns: The corresponding text location.
  /// 
  func textLocation(for location: Int) -> NSTextLocation? {
    self.location(documentRange.location, offsetBy: location)
  }

  /// Convert a text range to a character range within this text content storage.
  ///
  /// - Parameter textRange: The text range to convert.
  /// - Returns: The corresponding character range in the underlying text storage.
  ///
  func range(for textRange: NSTextRange) -> NSRange {
    NSRange(location: offset(from: documentRange.location, to: textRange.location),
            length: offset(from: textRange.location, to: textRange.endLocation))
  }
  
  /// Convert a character range to a text range within this text content storage.
  ///
  /// - Parameter range: The character range to convert.
  /// - Returns: The corresponding text range in the underlying text storage.
  ///
  func textRange(for range: NSRange) -> NSTextRange? {
    if let start = location(documentRange.location, offsetBy: range.location),
       let end   = location(start, offsetBy: range.length)
    {
      return NSTextRange(location: start, end: end)
    } else { return nil }
  }
}

