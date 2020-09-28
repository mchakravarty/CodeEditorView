//
//  TextView.swift
//  
//
//  Created by Manuel M T Chakravarty on 28/09/2020.
//
//  Text view protocol extracts common functionality between 'UITextView' and 'NSTextView'.

import Foundation


/// A protocol that bundles up the commonalities of 'UITextView' and 'NSTextView'.
///
protocol TextView {
  var layoutManager: NSLayoutManager { get }
  var textContainer: NSTextContainer { get }
  var textStorage:   NSTextStorage   { get }
}


#if os(iOS)

import UIKit

extension UITextView: TextView { }


#elseif os(macOS)

import AppKit

extension NSTextView: TextView { }


#endif
