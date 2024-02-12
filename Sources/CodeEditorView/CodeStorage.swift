//
//  CodeStorage.swift
//
//  Created by Manuel M T Chakravarty on 09/01/2021.
//
//  This file contains `NSTextStorage` extensions for code editing.

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import LanguageSupport


#if os(iOS) || os(visionOS)
typealias EditActions = NSTextStorage.EditActions
#elseif os(macOS)
typealias EditActions = NSTextStorageEditActions
#endif



// MARK: -
// MARK: `NSTextStorage` subclass

// `NSTextStorage` is a class cluster; hence, we realise our subclass by decorating an embeded vanilla text storage.
class CodeStorage: NSTextStorage {

  fileprivate let textStorage: NSTextStorage = NSTextStorage()

  var theme: Theme
  

  // MARK: Initialisers

  init(theme: Theme) {
    self.theme = theme
    super.init()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  #if os(macOS)
  @available(*, unavailable)
  required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
    fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
  }
  #endif


  // MARK: Interface to override for subclass

  override var string: String { textStorage.string }

  // We access attributes through the API of the wrapped `NSTextStorage`; hence, lazy attribute fixing keeps working as
  // before. (Lazy attribute fixing dramatically impacts performance due to syntax highlighting cutting the text up
  // into lots of short attribute ranges.)
  override var fixesAttributesLazily: Bool { true }

  override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
    return textStorage.attributes(at: location, effectiveRange: range)
  }

  // Extended to handle auto-deletion of adjacent matching brackets
  override func replaceCharacters(in range: NSRange, with str: String) {

    beginEditing()

    // We are deleting one character => check whether it is a one-character bracket and if so also delete its matching
    // bracket if it is directly adjacent
    if range.length == 1 && str.isEmpty,
       let deletedToken = token(at: range.location).token,
       let language     = (delegate as? CodeStorageDelegate)?.language,
       deletedToken.token.isOpenBracket
        && range.location + 1 < string.utf16.count
        && language.lexeme(of: deletedToken.token)?.count == 1
        && token(at: range.location + 1).token?.token == deletedToken.token.matchingBracket
    {

      let extendedRange = NSRange(location: range.location, length: 2)
      textStorage.replaceCharacters(in: extendedRange, with: "")
      edited(.editedCharacters, range: extendedRange, changeInLength: -2)

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

extension NSAttributedString.Key {

  /// Attribute to indicate that an attribute run has the default styling and not a token-specific styling.
  ///
  static let hideInvisibles: NSAttributedString.Key = .init("hideInvisibles")
}

extension CodeStorage {
  
  /// Returns the theme colour for a line token.
  ///
  /// - Parameter linetoken: The line token whose colour is desired.
  /// - Returns: The theme colour of the given line token.
  ///
  func colour(for linetoken: LineToken) -> OSColor {
    switch linetoken.kind {
    case .comment: theme.commentColour
    case .token(let token):
      switch token {
      case .string:     theme.stringColour
      case .character:  theme.characterColour
      case .number:     theme.numberColour
      case .identifier: theme.identifierColour
      case .keyword:    theme.keywordColour
      default:          theme.textColour
      }
    }
  }

  func setHighlightingAttributes(for range: NSRange, in layoutManager: NSTextLayoutManager)
  {
    // We cannot inline the body of the task, because `setRenderingAttributes` will not correctly interpret the text
    // ranges in the case that we are in an edit operation. It is also undesirable to dispatch this block to the main
    // queue as this will introduce a visible delay in the rendering of the highlighting.
    //
    // The "non-sendable type" warnings are rather unfortunate, but I don't have a better solution right now.
    // Suggestions are welcome!
    Task {
      guard let contentStorage = layoutManager.textContentManager as? NSTextContentStorage
      else { return }

      if let textRange = contentStorage.textRange(for: range) {
        layoutManager.setRenderingAttributes([.foregroundColor: theme.textColour, .hideInvisibles: ()],
                                             for: textRange)
      }
      enumerateTokens(in: range) { lineToken in

        if let documentRange = lineToken.range.intersection(range),
           let textRange     = contentStorage.textRange(for: documentRange)
        {
          let colour = colour(for: lineToken)
          layoutManager.setRenderingAttributes([.foregroundColor: colour], for: textRange)
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
  
  /// Token representation for token enumeration, which includes simple tokens and comment spans.
  ///
  /// NB: In this representation tokens and comments never extend across lines.
  ///
  struct LineToken {
    enum Kind {
      case comment
      case token(LanguageConfiguration.Token)
    }

    /// Token range, relative to the start of the document.
    ///
    let range: NSRange

    /// Token start position, relative to the line on which the token is located.
    ///
    let column: Int

    /// The kind of token.
    ///
    let kind: Kind
    
    /// Whether the line token represents a comment.
    ///
    var isComment: Bool {
      switch kind {
      case .comment: true
      default:       false
      }
    }
  }
  
  /// Enumerate tokens and comment spans from the given location onwards.
  ///
  /// - Parameters:
  ///   - location: The location where the enumeration starts.
  ///   - block: A block invoked for every token that also determines if the enumeration finishes early.
  ///
  /// The first enumerated token may have a starting location smaller than `location` (but it will extent until at least
  /// `location`). Enumeration proceeds until the end of the document or until `block` returns `false`.
  ///
  func enumerateTokens(from location: Int, using block: (LineToken) -> Bool) {

    // Enumerate the comemnt ranges and tokens on one line and optionally skip everything before a given start
    // location. We can have tokens inside comment ranges. These tokens are being skipped. (We don't highlight inside
    // comments, so far.) If a token and a comment begin at the same location, the comment takes precedence.
    func enumerate(tokens: [LanguageConfiguration.Tokeniser.Token],
                   commentRanges: [NSRange],
                   lineStart: Int,
                   startLocation: Int?)
    -> Bool
    {
      var skipUntil: Int? = startLocation  // tokens from this location onwards (even in part) are enumerated

      var tokens        = tokens
      var commentRanges = commentRanges
      while !tokens.isEmpty || !commentRanges.isEmpty {

        let token        = tokens.first,
            commentRange = commentRanges.first
        if let token,
           (commentRange?.location ?? Int.max) > token.range.location {

          if skipUntil ?? 0 <= token.range.max - 1,
             let range = token.range.shifted(by: lineStart)
          {
            let doContinue = block(LineToken(range: range, column: token.range.location, kind: .token(token.token)))
            if !doContinue { return false }
          }
          tokens.removeFirst()

        } else if let commentRange {

          if skipUntil ?? 0 <= commentRange.max - 1,
             let range = commentRange.shifted(by: lineStart)
          {
            let doContinue = block(LineToken(range: range, column: commentRange.location, kind: .comment))
            if !doContinue { return false }
            skipUntil = commentRange.max      // skip tokens within the comment range
          }
          commentRanges.removeFirst()
        }
      }
      return true
    }

    guard let lineMap   = (delegate as? CodeStorageDelegate)?.lineMap,
          let startLine = lineMap.lineContaining(index: location)
    else { return }

    let firstLine = lineMap.lines[startLine]
    if let info = firstLine.info {

      let doContinue = enumerate(tokens: info.tokens,
                                 commentRanges: info.commentRanges,
                                 lineStart: firstLine.range.location,
                                 startLocation: location - firstLine.range.location)
      if !doContinue { return }

    }

    for line in lineMap.lines[startLine + 1 ..< lineMap.lines.count] {

      if let info = line.info {

        let doContinue = enumerate(tokens: info.tokens,
                                   commentRanges: info.commentRanges,
                                   lineStart: line.range.location,
                                   startLocation: nil)
        if !doContinue { return }

      }
    }
  }
  
  /// Enumerate tokens and comment spans in the given range.
  ///
  /// - Parameters:
  ///   - range: The range whose tokens are being enumerated. The first and last token may extend left and right
  ///       outside the given range.
  ///   - block: A block invoked foro every range.
  ///
  func enumerateTokens(in range: NSRange, using block: (LineToken) -> Void) {
    enumerateTokens(from: range.location) { token in

      block(token)
      return token.range.max < range.max
    }
  }
  
  /// Return all tokens in the given range.
  ///
  /// - Parameter range: The range whose tokens are returned.
  /// - Returns: An array containing the tokens in the range, where first and last token may extend left and right
  ///     outside the given range.
  ///
  func tokens(in range: NSRange) -> [LineToken] {
    var tokens: [LineToken] = []
    enumerateTokens(in: range) { tokens.append($0) }
    return tokens
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


// MARK: -
// MARK: Text content storage

class CodeContentStorage: NSTextContentStorage {

  override func processEditing(for textStorage: NSTextStorage,
                               edited editMask: EditActions,
                               range newCharRange: NSRange,
                               changeInLength delta: Int,
                               invalidatedRange invalidatedCharRange: NSRange)
  {
    super.processEditing(for: textStorage,
                         edited: editMask,
                         range: newCharRange,
                         changeInLength: delta,
                         invalidatedRange: invalidatedCharRange)

    // NB: We need to wait until after the content storage has processed the edit before text locations (and ranges)
    //     match characters counts in the backing store again.
    if let codeStorageDelegate   = textStorage.delegate as? CodeStorageDelegate,
       let invalidationRange     = codeStorageDelegate.tokenInvalidationRange,
       let invalidationTextRange = textRange(for: invalidationRange)
    {
      for textLayoutManager in textLayoutManagers {

        // Invalidate the rendering attributes for syntax highlighting in the entire invalidated token range.
        textLayoutManager.invalidateRenderingAttributes(for: invalidationTextRange)
        if delta > 1,
           let textLayoutManagerDelegate = textLayoutManager.delegate,
           textLayoutManagerDelegate.isKind(of: MinimapTextLayoutManagerDelegate.self)
        {

          // MARK: [Note Minimap Redraw Voodoo]
          // Getting the minimap to redraw properly in case of changes affecting a larger area has proven difficult
          // and OS-specific. It depends on timing and concurrency issues in the text system and I haven't been able to
          // find a reliable way of tackling this problem.
          //
          // Below is a partial fix for macOS and iOS, but visionOS also requires invalidation code in the
          // `textDidChangeNotification` observer configured in during initialisation of the `UITextView`-flavour of
          // `CodeView`.
          //
          // If larger amounts of text are added, we need to invalidate the layout of the minimap (i.e., secondary)
          // layout manager explicitly. We cannot do that inline, though, if we don't want to risk a deadlock (as
          // experience shows). Hence, we delay that action by enqueueing this operation. This does, unfortunately, lead
          // to a visible delay on macOS, which I don't know how to avoid at the moment.
          Task { @MainActor in
            if let invalidationTextRange = textRange(for: invalidationRange) {
#if os(iOS) || os(visionOS)
              // For some reason, for the voodoo to work, we need to ensure layour first on iOS...
              textLayoutManager.ensureLayout(for: invalidationTextRange)
#endif
              textLayoutManager.invalidateLayout(for: invalidationTextRange)  // warning is bogus as this will run on the main thread
            }
          }
        }
      }
    }
  }
}
