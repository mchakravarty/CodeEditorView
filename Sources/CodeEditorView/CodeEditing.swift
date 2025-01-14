//
//  CodeEditing.swift
//  CodeEditorView
//
//  Created by Manuel M T Chakravarty on 06/01/2025.
//
//  This file implements common code editing operations.

import SwiftUI

import LanguageSupport


// MARK: -
// MARK: Actions and commands

//extension CodeView {
//
//#if os(macOS)
//  override func performKeyEquivalent(with event: NSEvent) -> Bool {
//
//    if event.charactersIgnoringModifiers == "/"
//        && event.modifierFlags.intersection([.command, .control, .option]) == .command
//    {
//
//      comment()
//      return true
//
//    } else {
//      return super.performKeyEquivalent(with: event)
//    }
//  }
//#endif
//}

/// Adds an "Editor" menu with code editing commands and adds a duplicate command to the pasteboard commands.
///
public struct CodeEditingCommands: Commands {

  public init() { }

  public var body: some Commands {

    CommandGroup(after: .pasteboard) {
      CodeEditingDuplicateCommandView()
    }

    CommandMenu("Editor") {
      CodeEditingCommandsView()
    }
  }
}

private func send(_ action: Selector) {
#if os(macOS)
  NSApplication.shared.sendAction(action, to: nil, from: nil)
#elseif os(iOS) || os(visionOS)
  UIApplication.shared.sendAction(action, to: nil, from: nil, for: nil)
#endif
}

/// Menu item for the duplicate command.
///
public struct CodeEditingDuplicateCommandView: View {

  public init() { }

  public var body: some View {

    Button("Duplicate") {
      send(#selector(CodeEditorActions.duplicate(_:)))
    }
    .keyboardShortcut("D", modifiers: [.command])
  }
}

/// Code editing commands that can, for example, be used in a `CommandMenu` or `CommandGroup`.
///
public struct CodeEditingCommandsView: View {

  public init() { }

  public var body: some View {

    Button("Re-Indent") {
      send(#selector(CodeEditorActions.reindent(_:)))
    }
    .keyboardShortcut("I", modifiers: [.control])
    Button("Shift Left") {
      send(#selector(CodeEditorActions.shiftLeft(_:)))
    }
    .keyboardShortcut("[", modifiers: [.command])
    Button("Shift Right") {
      send(#selector(CodeEditorActions.shiftRight(_:)))
    }
    .keyboardShortcut("]", modifiers: [.command])

    Divider()

    Button("Comment Selection") {
      send(#selector(CodeEditorActions.commentSelection(_:)))
    }
    .keyboardShortcut("/", modifiers: [.command])
  }
}

/// Protocol with all code editor actions for maximum flexibility in invoking them via the responder chain.
///
@objc public protocol CodeEditorActions {

  func duplicate(_ sender: Any?)
  func reindent(_ sender: Any?)
  func shiftLeft(_ sender: Any?)
  func shiftRight(_ sender: Any?)
  func commentSelection(_ sender: Any?)
}

extension CodeView: CodeEditorActions {

  @objc func duplicate(_ sender: Any?) { duplicate() }
  @objc func reindent(_ sender: Any?) { reindent() }
  @objc func shiftLeft(_ sender: Any?) { shiftLeftOrRight(doShiftLeft: true) }
  @objc func shiftRight(_ sender: Any?) { shiftLeftOrRight(doShiftLeft: false) }
  @objc func commentSelection(_ sender: Any?) { comment() }
}

// MARK: -
// MARK: Override tab key behaviour

extension CodeView {

#if os(macOS)

  override public func keyDown(with event: NSEvent) {

    let noModifiers = event.modifierFlags.intersection([.shift, .control, .option, .command]) == []
    if event.keyCode == keyCodeTab && noModifiers {
      insertTab()
    } else if event.keyCode == keyCodeReturn && noModifiers {
      insertReturn()
    } else {
      super.keyDown(with: event)
    }
  }

#elseif os(iOS) || os(visionOS)

  override var keyCommands: [UIKeyCommand] {
    [ UIKeyCommand(input: "\t", modifierFlags: [], action: #selecctor(insertTab))
    ]
  }

#endif
}

// MARK: -
// MARK: Selections

extension NSRange {

  /// Adjusts the selection represneted by `self` in accordance with replacing the characters in the given range with
  /// the given number of replacement characters.
  ///
  /// - Parameters:
  ///   - range: The range that is being replaced.
  ///   - delta: The number of characters in the replacement string.
  ///
  func adjustSelection(forReplacing range: NSRange, by length: Int) -> NSRange {

    let delta = length - range.length
    if let overlap = intersection(range) {

      if location <= range.location {

        if max >= range.max {
          // selection encompasses the whole replaced range
          return shifted(endBy: delta) ?? self
        } else {
          // selection overlaps with a proper prefix of the replaced range
          if range.length - overlap.length < -delta {
            // text shrinks sufficiently that the selection needs to shrink, too
            return shifted(endBy: -delta - (range.length - overlap.length)) ?? NSRange(location: location, length: 0)
          } else {
            return self
          }
        }

      } else {

        // selection overlaps with a proper suffix of the replaced range or is contained in the replaced range
        if range.length - overlap.length < -delta {
          // text shrinks sufficiently that the selection needs to shrink, too
          return shifted(endBy: -delta - (range.length - overlap.length)) ?? NSRange(location: location, length: 0)
        } else {
          return self
        }

      }

    } else {

      if location <= range.location {
        // selection is in front of the replaced text
        return self
      } else {
        // selection is behind the replaced text
        return shifted(by: delta) ?? self
      }
    }
  }
}


// MARK: -
// MARK: Editing functionality

extension CodeEditor.IndentationConfiguration {
  
  /// String of whitespace that indents from the start of the line to the first indentation point.
  ///
  var defaultIndentation: String { indentation(for: indentWidth) }
  
  /// Yield the whitespace string realising the indentation up to `column` under the current configuration.
  ///
  /// - Parameter column: The desired indentation.
  /// - Returns: A string that realises that indentation.
  ///
  func indentation(for column: Int) -> String {
    switch preference {
    case .preferSpaces:
      String(repeating: " ", count: column)
    case .preferTabs:
      String(repeating: "\t", count: column / tabWidth) + String(repeating: " ", count: column % tabWidth)
    }
  }

  /// Determine the column index of the first character that is neither a tab or space character in the given line
  /// string or the end index of the line.
  ///
  /// - Parameter line: The string containing the characters of the line.
  /// - Returns: The (character) index of the first character that is neither space nor tab or the end index of the line.
  ///
  /// NB: If the line contains only space and tab characters, the result will be the length of the string.
  ///
  func currentIndentation(in line: any StringProtocol) -> Int {

    let index = (line.firstIndex{ !($0 == " " || $0 == "\t") }) ?? line.endIndex
    return index.utf16Offset(in: line)
  }

  /// Determine the column index of the first character that is neither a tab or space character in the given line
  /// string if there is any.
  ///
  /// - Parameter line: The string containing the characters of the line.
  /// - Returns: The (character) index of the first character that is neither space nor tab or nil if there is no such
  ///     character or if that character is a whitespace (notably a newline charachter).
  ///
  func startOfText(in line: any StringProtocol) -> Int? {

    if let index = (line.firstIndex{ !($0 == " " || $0 == "\t") }) {
      if line[index].isWhitespace { return nil } else { return index.utf16Offset(in: line) }
    } else { return nil }
  }
}

extension CodeView {
  
  /// Shift all lines that are part of the current selection one indentation level to the left or right.
  ///
  func shiftLeftOrRight(doShiftLeft: Bool) {
    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }

    func shift(line: Int, adjusting range: NSRange) -> NSRange {
      guard let theLine = codeStorageDelegate.lineMap.lookup(line: line)
      else { return range }

      if doShiftLeft {

        var location        = theLine.range.location
        var length          = 0
        var remainingIndent = indentation.indentWidth
        var reminder        = ""
        while remainingIndent > 0 {

          guard let characterRange = Range<String.Index>(NSRange(location: location, length: 1), in: codeStorage.string)
          else { return range }
          let character = codeStorage.string[characterRange]
          if character == " " {

            remainingIndent -= 1
            length          += 1

          } else if character == "\t" {

            let tabWidth  = indentation.tabWidth,
                tabIndent = if length % tabWidth == 0 { tabWidth } else { tabWidth - length % tabWidth }
            if tabIndent > remainingIndent {

              // We got a tab character, but the remaining identation to remove is less than the tabs indentation at
              // this point => replace the tab by as many spaces as indentation needs to remain.
              remainingIndent = 0
              reminder += String(repeating: " ", count: tabIndent - remainingIndent)

            } else {
              remainingIndent -= tabIndent
            }
            length += 1

          } else {
            // Stop if we hit a character that is neither a space or tab character.
            remainingIndent = 0
          }
          location += 1
        }

        let replacementRange = NSRange(location: theLine.range.location, length: length)
        codeStorage.replaceCharacters(in: replacementRange, with: reminder)
        return range.adjustSelection(forReplacing: replacementRange, by: reminder.utf16.count)

      } else {

        let replacementRange = NSRange(location: theLine.range.location, length: 0)
        codeStorage.replaceCharacters(in: replacementRange, with: indentation.defaultIndentation)
        return range.adjustSelection(forReplacing: replacementRange, by: 2)

      }
    }

    textContentStorage.performEditingTransaction {
      processSelectedRanges { range in

        let lines = codeStorageDelegate.lineMap.linesContaining(range: range)
        var newRange = range
        for line in lines {
          newRange = shift(line: line, adjusting: newRange)
        }
        return newRange
      }
    }
  }

  /// Comment or uncomment the selection or multiple lines.
  ///
  /// For each selection range in the current selection, proceed as follows:
  ///
  /// 1. If the selection has zero length (it is an insertion point), comment or uncomment the line where the selection
  ///    is located.
  /// 2. If the selection has a length greater zero, but does not extend across a line end, enclose the selection in
  ///    nested comments or remove the nested comment brackets, if the selection is already enclosed in comments. In the
  ///    latter case, the selection may (partially) include the comment brackets. This is unless the selected range
  ///    totally or partially covers commented text. In that case, proceed as if the selection had zero length.
  /// 3. If the selection extends across multiple lines, comment all lines, unless the first and last line are already
  ///    commented. In the latter case, uncomment all commented lines.
  ///
  func comment() {
    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }

    // Determine whether the leading token on the given line is a single line comment token.
    func isCommented(line: Int) -> Bool {
      guard let theLine = codeStorageDelegate.lineMap.lookup(line: line) else { return false }

      return theLine.info?.tokens.first?.token == .singleLineComment
    }

    // Insert single line comment token at the start of the line.
    func comment(line: Int, with range: NSRange) -> NSRange {
      guard let theLine                 = codeStorageDelegate.lineMap.lookup(line: line),
            let singleLineCommentString = language.singleLineComment
      else { return range }

      // Insert single line comment
      let replacementRange = NSRange(location: theLine.range.location, length: 0)
      codeStorage.replaceCharacters(in: replacementRange, with: singleLineCommentString)
      return range.adjustSelection(forReplacing: replacementRange, by: singleLineCommentString.count)
    }
    
    // Remove leading single line comment token (if any).
    func uncomment(line: Int, with range: NSRange) -> NSRange {
      guard let theLine = codeStorageDelegate.lineMap.lookup(line: line) else { return range }

      if let firstToken = theLine.info?.tokens.first,
         firstToken.token == .singleLineComment,
         let tokenRange = firstToken.range.shifted(by: theLine.range.location)
      {

        codeStorage.deleteCharacters(in: tokenRange)
        return range.adjustSelection(forReplacing: tokenRange, by: 0)

      } else {
        return range
      }
    }

    // Determine whether the selection is fully enclosed in a bracketed comment on the given line. If so, return the
    // comment range (wrt to the whole document).
    func isCommentBracketed(range: NSRange, on line: Int) -> NSRange? {
      guard let theLine       = codeStorageDelegate.lineMap.lookup(line: line),
            let tokens        = theLine.info?.tokens,
            let commentRanges = theLine.info?.commentRanges,
            let localRange    = range.shifted(by: -theLine.range.location)
      else { return nil }

      for commentRange in commentRanges {
        if commentRange.intersection(localRange) == localRange
            && (tokens.contains{ $0.range.location == commentRange.location && $0.token == .nestedCommentOpen })
        {
          return commentRange.shifted(by: theLine.range.location)
        }
      }
      return nil
    }

    // Add comment brackets around the given range.
    func commentBracket(range: NSRange) -> NSRange {
      guard let (openString, closeString) = language.nestedComment else { return range }

      codeStorage.replaceCharacters(in: NSRange(location: range.max, length: 0), with: closeString)
      codeStorage.replaceCharacters(in: NSRange(location: range.location, length: 0), with: openString)
      return range.shifted(by: openString.count) ?? range
    }

    // Remove comment brackets at the ends of the given comment range.
    func uncommentBracket(range: NSRange, in commentRange: NSRange) -> NSRange {
      guard let (openString, closeString) = language.nestedComment else { return range }

      codeStorage.deleteCharacters(in: NSRange(location: commentRange.max - closeString.count,
                                               length: closeString.count))
      codeStorage.deleteCharacters(in: NSRange(location: commentRange.location, length: openString.count))
      let newCommentRange = commentRange.shifted(by: -openString.count)?.shifted(endBy: -closeString.count) ?? commentRange
      return (range.shifted(by: -openString.count) ?? range).intersection(newCommentRange) ?? range
    }

    textContentStorage.performEditingTransaction {
      processSelectedRanges { range in

        let lines = codeStorageDelegate.lineMap.linesContaining(range: range)
        guard let firstLine = lines.first else { return range }

        var newRange = range
        if range.length == 0 {

          // Case 1 of the specification
          newRange = if isCommented(line: firstLine) {
                       uncomment(line: firstLine, with: range)
                     } else {
                       comment(line: firstLine, with: range)
                     }

        } else if lines.count == 1 {

          // Case 2 of the specification
          guard let theLine = codeStorageDelegate.lineMap.lookup(line: firstLine) else { return range }
          let lineLocation = range.location - theLine.range.location
          if let commentRange = isCommentBracketed(range: range, on: firstLine) {
            newRange = uncommentBracket(range: range, in: commentRange)
          } else {

            let partiallyCommented = theLine.info?.commentRanges.contains{ $0.contains(lineLocation)
                                      || $0.contains(lineLocation + range.length) }
            if partiallyCommented == true {

              if isCommented(line: firstLine) {
                newRange = uncomment(line: firstLine, with: range)
              } else {
                newRange = comment(line: firstLine, with: range)
              }

            } else {
              newRange = commentBracket(range: range)
            }

          }

        } else {

          // Case 3 of the specification
          // NB: It is crucial to process lines in reverse order as any text change invalidates ranges in the line map
          //     after the change.
          guard let lastLine = lines.last else { return range }
          if isCommented(line: firstLine) && isCommented(line: lastLine) {
            for line in lines.reversed() { newRange = uncomment(line: line, with: newRange) }
          } else {
            for line in lines.reversed() { newRange = comment(line: line, with: newRange) }
          }

        }
        return newRange
      }
    }
  }

  func duplicate() {
    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }

    /// Duplicate the given range right after the end of the original range and eturn the range of the duplicate.
    ///
    func duplicate(range: NSRange) -> NSRange {

      guard let text = codeStorage.string[range] else { return range }
      codeStorage.replaceCharacters(in: NSRange(location: range.max, length: 0), with: String(text))
      return NSRange(location: range.max, length: range.length)
    }

    textContentStorage.performEditingTransaction {
      processSelectedRanges { range in

        if range.length == 0 {

          guard let line      = codeStorageDelegate.lineMap.lineOf(index: range.location),
                let lineRange = codeStorageDelegate.lineMap.lookup(line: line)?.range
          else { return range }
          let _ = duplicate(range: lineRange)
          return NSRange(location: range.location + lineRange.length, length: 0)

        } else {
          return duplicate(range: range)
        }
      }
    }
  }
  
  /// Indent all lines currently selected.
  ///
  func reindent() {
    guard let textContentStorage = optTextContentStorage else { return }

    textContentStorage.performEditingTransaction {
      processSelectedRanges { reindent(range: $0) }
    }
  }

  private func reindent(range: NSRange) -> NSRange {

    guard let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate else {
      return range
    }

    // Determine the column index of the first character that is neither a space nor a tab character. It can be a
    // newline or the end of the line.
    func currentIndentation(of line: Int) -> Int? {

      guard let lineInfo  = codeStorageDelegate.lineMap.lookup(line: line),
            let textRange = Range<String.Index>(lineInfo.range, in: codeStorage.string)
      else { return nil }
      return indentation.currentIndentation(in: codeStorage.string[textRange])
    }

    // Determine the column index of the first non-whitespace character.
    func startOfText(of line: Int) -> Int? {

      guard let lineInfo  = codeStorageDelegate.lineMap.lookup(line: line),
            let textRange = Range<String.Index>(lineInfo.range, in: codeStorage.string)
      else { return nil }
      return indentation.startOfText(in: codeStorage.string[textRange]) ?? 0
    }

    func predictedIndentation(for line: Int) -> Int {
      if language.indentationSensitiveScoping {

        // FIXME: We might want to cache that information.

        var scannedLine = line
        while scannedLine >= 0 {

          if let index = startOfText(of: scannedLine) { return index }
          else {
            scannedLine -= 1
          }

        }
        return 0

      } else {

        // FIXME: Only languages in the C tradition use curly braces for scoping. Needs to be more flexible.
        guard let lineInfo = codeStorageDelegate.lineMap.lookup(line: line) else { return 0 }
        return (lineInfo.info?.curlyBracketDepthStart ?? 0) * indentation.indentWidth

      }
    }

    let lines = codeStorageDelegate.lineMap.linesContaining(range: range)
    guard let firstLine = lines.first else { return range }

    if range.length == 0 {

      let desiredIndent = predictedIndentation(for: firstLine)
      guard let currentIndent = currentIndentation(of: firstLine),
            let lineInfo      = codeStorageDelegate.lineMap.lookup(line: firstLine)
      else { return range }
      codeStorage.replaceCharacters(in: NSRange(location: lineInfo.range.location, length: currentIndent),
                                    with: indentation.indentation(for: desiredIndent))
      return NSRange(location: lineInfo.range.location + desiredIndent, length: 0)

    } else {

      var newRange = range
      for line in lines {

        let desiredIndent = predictedIndentation(for: line)
        guard let currentIndent = currentIndentation(of: line),
              let lineInfo      = codeStorageDelegate.lineMap.lookup(line: line)
        else { return newRange }
        let replacementRange = NSRange(location: lineInfo.range.location, length: currentIndent),
            indentString     = indentation.indentation(for: desiredIndent)
        codeStorage.replaceCharacters(in: replacementRange, with: indentString)
        newRange = newRange.adjustSelection(forReplacing: replacementRange, by: indentString.count)

      }
      return newRange

    }
  }

  /// Implements the indentation behaviour for the tab key.
  ///
  /// * Whether to insert a tab character or spaces depends on the indentation configuration, which also determines tab
  ///   and indentation width.
  /// * Depending on the setting, inserting a tab triggers indenting the current line or actually inserting a tab
  ///   equivalent.
  /// * If the selection has length greater 0, a tab equivalent is always inserted.
  /// * If the selection spans multiple lines, the lines are always indented.
  ///
  func insertTab() {

    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }
    
    // Determine the column index of the first character that is neither a space nor a tab character. It can be a
    // newline or the end of the line.
    func currentIndentation(of line: Int) -> Int? {

      guard let lineInfo  = codeStorageDelegate.lineMap.lookup(line: line),
            let textRange = Range<String.Index>(lineInfo.range, in: codeStorage.string)
      else { return nil }
      return indentation.currentIndentation(in: codeStorage.string[textRange])
    }

    func insertTab(in range: NSRange) -> NSRange {

      let nextTabStopIndex = (range.location / indentation.tabWidth + 1) * indentation.tabWidth
      let replacementString = if indentation.preference == .preferTabs { "\t" }
                              else { String(repeating: " ", count: nextTabStopIndex - range.location) }
      codeStorage.replaceCharacters(in: range, with: replacementString)

      return NSRange(location: range.location + replacementString.utf16.count, length: 0)
    }

    switch indentation.tabKey {

    case .identsInWhitespace:
      textContentStorage.performEditingTransaction {
        processSelectedRanges { range in

          if range.length > 0 { return insertTab(in: range) }
          else {

            guard let firstLine   = codeStorageDelegate.lineMap.lineOf(index: range.location),
                  let lineInfo    = codeStorageDelegate.lineMap.lookup(line: firstLine),
                  let indentDepth = currentIndentation(of: firstLine)
            else { return range }
            let newRange = if range.location - lineInfo.range.location < indentDepth { reindent(range: range) }
                          else { insertTab(in: range) }
            return newRange

          }
        }
      }

    case .indentsAlways:
      textContentStorage.performEditingTransaction {
        processSelectedRanges { reindent(range: $0) }
      }

    case .insertsTab:
      textContentStorage.performEditingTransaction {
        processSelectedRanges { insertTab(in: $0) }
      }

    }
  }

  func insertReturn () {

    guard let textContentStorage  = optTextContentStorage,
          let codeStorage         = optCodeStorage,
          let codeStorageDelegate = codeStorage.delegate as? CodeStorageDelegate
    else { return }

    func predictedIndentation(after index: Int) -> Int {
      guard let line     = codeStorageDelegate.lineMap.lineOf(index: index),
            let lineInfo = codeStorageDelegate.lineMap.lookup(line: line)
      else { return 0 }
      let columnIndex = index - lineInfo.range.lowerBound

      if language.indentationSensitiveScoping {

        let range = NSRange(location: lineInfo.range.lowerBound, length: index - lineInfo.range.lowerBound)
        guard let stringRange = Range<String.Index>(range, in: codeStorage.string) else { return 0 }
        let indentString = codeStorage.string[stringRange].prefix(while: { $0 == " " || $0 == "\t" })
        return indentString.count

      } else {

        // FIXME: Only languages in the C tradition use curly braces for scoping. Needs to be more flexible.
        guard let info = lineInfo.info else { return 0 }
        let curlyBracketDepth = info.curlyBracketDepthStart,
            initialTokens     = info.tokens.prefix{ $0.range.lowerBound < columnIndex },
            openCurlyBrackets = initialTokens.reduce(0) {
              $0 + ($1.token == LanguageConfiguration.Token.curlyBracketOpen ? 1 : 0)
            },
            closeCurlyBrackets = initialTokens.reduce(0) {
              $0 + ($1.token == LanguageConfiguration.Token.curlyBracketClose ? 1 : 0)
            }
        return (curlyBracketDepth + openCurlyBrackets - closeCurlyBrackets) * indentation.indentWidth

      }
    }

    textContentStorage.performEditingTransaction {
      processSelectedRanges { range in

        let desiredIndent = if indentation.indentOnReturn { predictedIndentation(after: range.location) } else { 0 }
        codeStorage.replaceCharacters(in: range, with: "\n" + indentation.indentation(for: desiredIndent))
        return NSRange(location: range.location + 1 + desiredIndent, length: 0)

      }
    }
  }

  /// Execute a block for each selected range, from back to front.
  ///
  /// - Parameter block: The block to be executed for each selection range, which may modify the underlying text storage
  ///     and returns a new selection range.
  ///
  func processSelectedRanges(with block: (NSRange) -> NSRange) {

    // NB: It is crucial to process selected ranges in reverse order as any text change invalidates ranges in the line
    //     map after the change.
#if os(macOS)
    let ranges = selectedRanges.reversed()
#elseif os(iOS) || os(visionOS)
    let ranges = [NSValue(range: selectedRange)]
#endif
    var newSelected: [NSRange] = []
    for rangeAsValue in ranges {
      let range = rangeAsValue.rangeValue

      let newRange = block(range)
      newSelected.append(newRange)
    }
#if os(macOS)
    if !newSelected.isEmpty { selectedRanges = newSelected.map{ NSValue(range: $0) } }
#elseif os(iOS) || os(visionOS)
    if let selection = newSelected.first { selectedRange = selection }
#endif
  }
}
