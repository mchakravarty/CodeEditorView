//
//  CodeStorage.swift
//
//  Created by Manuel M T Chakravarty on 09/01/2021.
//
//  This file contains `NSTextStorage` extensions for code editing.

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import LanguageSupport


// MARK: -
// MARK: `NSTextStorage` subclass

// `NSTextStorage` is a class cluster; hence, we realise our subclass by decorating an embeded vanilla text storage.
class CodeStorage: NSTextStorage {

  let textStorage: NSTextStorage = NSTextStorage()

  var theme: Theme

  override var string: String { textStorage.string }

  init(theme: Theme) {
    self.theme = theme
    super.init()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  #if os(macOS)
  required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
    fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
  }
  #endif

  // We access attributes through the API of the wrapped `NSTextStorage`; hence, lazy attribute fixing keeps working as
  // before. (Lazy attribute fixing dramatically impacts performance due to syntax highlighting cutting the text up
  // into lots of short attribute ranges.)
  override var fixesAttributesLazily: Bool { true }

  override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {

    var attributes       = textStorage.attributes(at: location, effectiveRange: range)
    var foregroundColour = theme.textColour
    var tokenRange: NSRange

    // Translate comment and token information to the appropriate foreground colour determined by the current theme.
    if let commentRange = comment(at: location) {

      tokenRange       = commentRange
      foregroundColour = theme.commentColour

    } else {

      // NB: We always get a range, even if there is no token. In that case, the range is the space between the next
      //     tokens (or a token and the line start or end).
      let tokenWithEffectiveRange = token(at: location)
      tokenRange = tokenWithEffectiveRange.effectiveRange

      if let token = tokenWithEffectiveRange.token {

        switch token.token {
        case .string:     foregroundColour = theme.stringColour
        case .character:  foregroundColour = theme.characterColour
        case .number:     foregroundColour = theme.numberColour
        case .identifier: foregroundColour = theme.identifierColour
        case .keyword:    foregroundColour = theme.keywordColour
        default: ()
        }
      }
    }

    // Crop the effective range to the token range.
    if let rangePtr = range,
       let newRange = rangePtr.pointee.intersection(tokenRange)
    { rangePtr.pointee = newRange }

    attributes[.foregroundColor] = foregroundColour
    return attributes
  }

  // Extended to handle auto-deletion of adjcent matching brackets
  override func replaceCharacters(in range: NSRange, with str: String) {

    beginEditing()

    // We are deleting one character => check whether it is a one-character bracket and if so also delete its matching
    // bracket if it is directly adjascent
    if range.length == 1 && str == "",
       let deletedToken = token(at: range.location).token,
       let language     = (delegate as? CodeStorageDelegate)?.language
    {

      let isOpen    = deletedToken.token.isOpenBracket,
          isBracket = isOpen || deletedToken.token.isCloseBracket,
          isSafe    = (isOpen && range.location + 1 < string.utf16.count) || range.location > 0,
          offset    = isOpen ? 1 : -1
      if isBracket && isSafe && language.lexeme(of: deletedToken.token)?.count == 1 &&
          token(at: range.location + offset).token?.token == deletedToken.token.matchingBracket
      {

        let extendedRange = NSRange(location: isOpen ? range.location : range.location - 1, length: 2)
        textStorage.replaceCharacters(in: extendedRange, with: "")
        edited(.editedCharacters, range: extendedRange, changeInLength: -2)
        setInsertionPointAfterDeletion(of: extendedRange)

      } else {

        textStorage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)

      }

    } else {

      textStorage.replaceCharacters(in: range, with: str)
      edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)

    }
    endEditing()
  }

  override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
    beginEditing()
    textStorage.setAttributes(attrs, range: range)
    edited(.editedAttributes, range: range, changeInLength: 0)
    endEditing()
  }
}


// MARK: -
// MARK: Custom handling of the insertion point

extension CodeStorage {

  /// Insert the given string, such that it safe in an ongoing insertion cycle and does leave the cursor (insertion
  /// point) in place if the insertion is at the location of the insertion point.
  ///
  func cursorInsert(string: String, at index: Int) {

    Dispatch.DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(10)){

      #if os(iOS)

      self.replaceCharacters(in: NSRange(location: index, length: 0), with: string)

      #elseif os(macOS)

      // Collect the text views, where we insert at the insertion point
      var affectedTextViews: [NSTextView] = []
      for layoutManager in self.layoutManagers {
        for textContainer in layoutManager.textContainers {

          if let textView = textContainer.textView, textView.selectedRange() == NSRange(location: index, length: 0) {
            affectedTextViews.append(textView)
          }
        }
      }

      self.replaceCharacters(in: NSRange(location: index, length: 0), with: string)

      // Reset the insertion point to the original (pre-insertion) position (as it will move after the inserted text on
      // macOS otherwise)
      for textView in affectedTextViews { textView.setSelectedRange(NSRange(location: index, length: 0)) }

      #endif
    }
  }

  /// Set the insertion point of all attached text views, where the selection intersects the given range, to the start
  /// of the range. This is safe in an editing cycle, as the selection setting is deferred until completion.
  ///
  /// - Parameter range: The deleted chracter range.
  ///
  func setInsertionPointAfterDeletion(of range: NSRange) {

    for layoutManager in self.layoutManagers {
      for textContainer in layoutManager.textContainers {

        if let codeContainer = textContainer as? CodeContainer,
           let textView      = codeContainer.textView,
           NSIntersectionRange(textView.selectedRange, range).length != 0
        {
          Dispatch.DispatchQueue.main.async{ textView.selectedRange = NSRange(location: range.location, length: 0) }
        }
      }
    }
  }
}


// MARK: -
// MARK: Token attributes

extension CodeStorage {

  /// Yield the token at the given position (column index) on the given line, if any.
  ///
  /// - Parameters:
  ///   - line: The line where we are looking for a token.
  ///   - position: The column index of the location of interest (0-based).
  /// - Returns: The token at the given position, if any, and the effective range of the token or token-free space,
  ///     respectively, in the entire text. (The range in the token is its line range, whereas the `effectiveRange`
  ///     is relative to the entire text storage.)
  ///
  func token(on line: Int, at position: Int) -> (token: LanguageConfiguration.Tokeniser.Token?, effectiveRange: NSRange)? {
    guard let lineMap  = (delegate as? CodeStorageDelegate)?.lineMap,
          let lineInfo = lineMap.lookup(line: line),
          let tokens   = lineInfo.info?.tokens
    else { return nil }

    // FIXME: This is fairly naive, especially for very long lines...
    var previousToken: LanguageConfiguration.Tokeniser.Token? = nil
    for token in tokens {

      if position < token.range.location {

        // `token` is already after `column`
        let afterPreviousTokenOrLineStart = previousToken?.range.max ?? 0
        return (token: nil, effectiveRange: NSRange(location: lineInfo.range.location + afterPreviousTokenOrLineStart,
                                                    length: token.range.location - afterPreviousTokenOrLineStart))

      } else if token.range.contains(position),
                let effectiveRange = token.range.shifted(by: lineInfo.range.location)
      {
        // `token` includes `column`
        return (token: token, effectiveRange: effectiveRange)
      }
      previousToken = token
    }

    // `column` is after any tokens (if any) on this line
    let afterPreviousTokenOrLineStart = previousToken?.range.max ?? 0
    return (token: nil, effectiveRange: NSRange(location: lineInfo.range.location + afterPreviousTokenOrLineStart,
                                                length: lineInfo.range.length - afterPreviousTokenOrLineStart))
  }

  /// Yield the token at the given storage index.
  ///
  /// - Parameter location: Character index into the text storage.
  /// - Returns: The token at the given position, if any, and the effective range of the token or token-free space,
  ///     respectively, in the entire text. (The range in the token is its line range, whereas the `effectiveRange`
  ///     is relative to the entire text storage.)
  ///
  /// NB: Token spans never exceed a line.
  ///
  func token(at location: Int) -> (token: LanguageConfiguration.Tokeniser.Token?, effectiveRange: NSRange) {
    if let lineMap  = (delegate as? CodeStorageDelegate)?.lineMap,
       let line     = lineMap.lineContaining(index: location),
       let lineInfo = lineMap.lookup(line: line),
       let result   = token(on: line, at: location - lineInfo.range.location)
    {
      return result
    }
    else { return (token: nil, effectiveRange: NSRange(location: location, length: 1)) }
  }

  /// Convenience wrapper for `token(at:)` that returns only tokens, but with a range in terms of the entire text
  /// storage (not line-local).
  ///
  func tokenOnly(at location: Int) -> LanguageConfiguration.Tokeniser.Token? {
    let tokenWithEffectiveRange = token(at: location)
    var token = tokenWithEffectiveRange.token
    token?.range = tokenWithEffectiveRange.effectiveRange
    return token
  }

  /// Determine whether the given location is inside a comment and, if so, return the range of the comment (clamped to
  /// the current line).
  ///
  /// - Parameter location: Character index into the text storage.
  /// - Returns: If `location` is inside a comment, return the range of the comment, clamped to line bounds, but in
  ///     terms of teh entire text.
  ///
  func comment(at location: Int) -> NSRange? {
    guard let lineMap       = (delegate as? CodeStorageDelegate)?.lineMap,
          let line          = lineMap.lineContaining(index: location),
          let lineInfo      = lineMap.lookup(line: line),
          let commentRanges = lineInfo.info?.commentRanges
    else { return nil }

    let column = location - lineInfo.range.location
    for commentRange in commentRanges {
      if column < commentRange.location { return nil }
      else if commentRange.contains(column) { return commentRange.shifted(by: lineInfo.range.location) }
    }
    return nil
  }

  /// If the given location is just past a bracket, return its matching bracket's token range if it exists and the
  /// matching bracket is within the given range of lines.
  ///
  /// - Parameters:
  ///   - location: Location just past (i.e., to the right of) the original bracket (maybe opening or closing).
  ///   - lines: Range of lines to consider for the matching bracket.
  /// - Returns: Character range of the lexeme of the matching bracket if it exists in the given line range `lines`.
  ///
  func matchingBracket(at location: Int, in lines: Range<Int>) -> NSRange? {
    guard let codeStorageDelegate = delegate as? CodeStorageDelegate,
          let lineAndPosition     = codeStorageDelegate.lineMap.lineAndPositionOf(index: location),
          lineAndPosition.position > 0,                 // we can't be *past* a bracket on the rightmost column
          let token               = token(on: lineAndPosition.line, at: lineAndPosition.position - 1)?.token,
          token.range.max == lineAndPosition.position,  // we need to be past the bracket, even if it is multi-character
          token.token.isOpenBracket || token.token.isCloseBracket
    else { return nil }

    let matchingBracketTokenType = token.token.matchingBracket,
        searchForwards           = token.token.isOpenBracket,
        allTokens                = codeStorageDelegate.lineMap.lookup(line: lineAndPosition.line)?.info?.tokens ?? []

    var currentLine = lineAndPosition.line
    var tokens      = searchForwards ? Array(allTokens.drop(while: { $0.range.location <= lineAndPosition.position }))
                                     : Array(allTokens.prefix(while: { $0.range.max < lineAndPosition.position }).reversed())
    var level       = 1

    while lines.contains(currentLine) {

      for currentToken in tokens {

        if currentToken.token == token.token { level += 1 }         // nesting just got deeper
        else if currentToken.token == matchingBracketTokenType {    // matching bracket found

          if level > 1 { level -= 1 }     // but we are not yet at the topmost nesting level
          else {                          // this is the one actually matching the original bracket

            if let lineStart = codeStorageDelegate.lineMap.lookup(line: currentLine)?.range.location {
              return currentToken.range.shifted(by: lineStart)
            } else { return nil }

          }
        }
      }

      // Get the tokens on the next (forwards or backwards) line and reverse them if we search backwards.
      currentLine += searchForwards ? 1 : -1
      tokens       = codeStorageDelegate.lineMap.lookup(line: currentLine)?.info?.tokens ?? []
      if !searchForwards { tokens = tokens.reversed() }

    }
    return nil
  }
}
