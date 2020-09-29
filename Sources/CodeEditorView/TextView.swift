//
//  TextView.swift
//  
//
//  Created by Manuel M T Chakravarty on 28/09/2020.
//
//  Text view protocol that extracts common functionality between 'UITextView' and 'NSTextView'.

import Foundation


/// A protocol that bundles up the commonalities of 'UITextView' and 'NSTextView'.
///
protocol TextView {
  var optLayoutManager: NSLayoutManager? { get }
  var optTextContainer: NSTextContainer? { get }
  var optTextStorage:   NSTextStorage?   { get }
}


#if os(iOS)

import UIKit

extension UITextView: TextView {

  var optLayoutManager: NSLayoutManager? { layoutManager }
  var optTextContainer: NSTextContainer? { textContainer }
  var optTextStorage:   NSTextStorage?   { textStorage }
}


#elseif os(macOS)

import AppKit

extension NSTextView: TextView {

  var optLayoutManager: NSLayoutManager? { layoutManager }
  var optTextContainer: NSTextContainer? { textContainer }
  var optTextStorage:   NSTextStorage?   { textStorage }
}


#endif
