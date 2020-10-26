//
//  CodeStorageDelegate.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//
//  'NSTextStorageDelegate' for code views compute, collect, store, and update additional information about the text
//  stored in the 'NSTextStorage' that they serve. This is needed to quickly navigate the text (e.g., at which character
//  position does a particular line start) and to support code-specific rendering (e.g., syntax highlighting).

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  private(set) var lineMap = LineMap<Void>(string: "")

  func textStorage(_ textStorage: NSTextStorage,
                   willProcessEditing editedMask: NSTextStorage.EditActions,
                   range editedRange: NSRange,
                   changeInLength delta: Int) {

    lineMap.updateAfterEditing(string: textStorage.string, range: editedRange, changeInLength: delta)
  }
}
