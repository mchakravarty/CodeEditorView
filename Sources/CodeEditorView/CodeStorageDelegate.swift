//
//  CodeStorageDelegate.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//
//  'NSTextStorageDelegate' for code views compute, collect, store, and update additional information about the text
//  stored in the 'NSTextStorage' that they serve. This is needed to quickly navigate the text (e.g., at which character
//  position does a particular line start) and to support code-specific rendering (e.g., syntax highlighting).
//
//  It also handles the language service, if available. We need to have the language service available here, as
//  functionality, such as semantic tokens, interacts with functionality in here, such as token highlighting. The code
//  view accesses the language service from here.

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import os

import Rearrange

import LanguageSupport


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "CodeStorageDelegate")


// MARK: -
// MARK: Visual debugging support

// FIXME: It should be possible to enable this via a defaults setting.
private let visualDebugging               = false
private let visualDebuggingEditedColour   = OSColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.3)
private let visualDebuggingLinesColour    = OSColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.3)
private let visualDebuggingTrailingColour = OSColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.3)
private let visualDebuggingTokenColour    = OSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)


// MARK: -
// MARK: Tokens

/// The supported comment styles.
///
enum CommentStyle {
  case singleLineComment
  case nestedComment
}

/// Information that is tracked on a line by line basis in the line map.
///
/// NB: We need the comment depth at the start and the end of each line as, during editing, lines are replaced in the
///     line map before comment attributes are recalculated. During this replacement, we lose the line info of all the
///     replaced lines.
///
struct LineInfo {

  /// Structure characterising a bundle of messages reported for a single line. It features a stable identity to be able
  /// to associate display information in separate structures. Messages are paired with the zero-based column index to
  /// which they refer.
  ///
  /// NB: We don't identify a message bundle by the line number on which it appears, because edits further up can
  ///     increase and decrease the line number of a given bundle. We need a stable identifier.
  ///
  struct MessageBundle: Identifiable {
    let id: UUID

    private(set)
    var messages: [(Int, Message)]

    init(messages: [(Int, Message)]) {
      self.id       = UUID()
      self.messages = messages
    }
    
    /// Add a message, such that it overrides its previous version if the message is already present.
    ///
    /// - Parameter message: The message to add.
    ///
    mutating func add(message: (Int, Message)) {
      if let idx = messages.firstIndex(where: {$0.1 == message.1}) {
        messages[idx] = message
      } else {
        messages.append(message)
      }
    }

    mutating func remove(message: Message) {
      if let idx = messages.firstIndex(where: {$0.1 == message}) {
        messages.remove(at: idx)
      }
    }
  }

  var commentDepthStart: Int   // nesting depth for nested comments at the start of this line
  var commentDepthEnd:   Int   // nesting depth for nested comments at the end of this line

  // FIXME: we are not currently using the following three variables (they are maintained, but they are never useful).
  var roundBracketDiff:  Int   // increase or decrease of the nesting level of round brackets on this line
  var squareBracketDiff: Int   // increase or decrease of the nesting level of square brackets on this line

  var curlyBracketDepthStart: Int   // nesting level of curly brackets aty the start of this line
  var curlyBracketDepthEnd:   Int   // nesting level of curly brackets aty the end of this line

  /// The tokens extracted from the text on this line.
  ///
  /// NB: The ranges contained in the tokens are relative to the *start of the line* and 0-based.
  ///
  var tokens: [LanguageConfiguration.Tokeniser.Token]

  /// Ranges of this line that are commented out.
  ///
  /// NB: The ranges are relative to the *start of the line* and 0-based.
  ///
  var commentRanges: [NSRange]

  /// The messages reported for this line.
  ///
  /// NB: The bundle may be non-nil, but still contain no messages (after all messages have been removed).
  ///
  var messages: MessageBundle? = nil
}


// MARK: -
// MARK: Helper functions for `LineMap<LineInfo>`

extension LineMap<LineInfo> {
  
  /// Checks whether the given range lies entirely within a comment range.
  ///
  /// - Parameter range: The range to query for.
  /// - Returns: Whether `range` lines within a comment range.
  /// 
  func isWithinComment(range: NSRange) -> Bool {
    guard let (line, position) = lineAndPositionOf(index: range.location),
          let (_, info)        = lookup(line: line),
          let commentRanges    = info?.commentRanges
    else { return false }

    let lineRange = NSRange(location: position, length: range.length)
    return commentRanges.contains{ $0.intersection(lineRange) == lineRange }
  }
}


// MARK: -
// MARK: Delegate class

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  private(set) var language:  LanguageConfiguration
  private      var tokeniser: LanguageConfiguration.Tokeniser?  // cache the tokeniser
  
  /// Language service for this document if available.
  /// 
  var languageService: LanguageService? { language.languageService }

  /// Hook to propagate changes to the text store upwards in the view hierarchy.
  ///
  let setText: (String) -> Void

  private(set) var lineMap = LineMap<LineInfo>(string: "")

  /// The message bundle IDs that got invalidated by the last editing operation because the code that they refer to got
  /// changed.
  ///
  private(set) var lastInvalidatedMessageIDs: [LineInfo.MessageBundle.ID] = []

  /// If the last text change was a one-character addition, which completed a token, then that token is remembered here
  /// together with its range until the next text change.
  ///
  private var lastTypedToken: LanguageConfiguration.Tokeniser.Token?
  
  /// Indicates that the language service is not to be notified of the next text change. (This is useful during
  /// (re)initialisation.)
  ///
  var skipNextChangeNotificationToLanguageService: Bool = false

  /// Indicates whether the current editing round is for a wholesale replacement of the text.
  /// 
  private(set) var processingStringReplacement: Bool = false

  /// Indicates whether the current editing round is for a one-character addition to the text.
  ///
  private(set) var processingOneCharacterAddition: Bool = false
  
  /// Contains the range of characters whose token information was invalidated by the last editing operation.
  ///
  private(set) var tokenInvalidationRange: NSRange? = nil

  /// Contains the number of lines affected by `tokenInvalidationRange`.
  ///
  private(set) var tokenInvalidationLines: Int? = nil

  /// Indicates the number of characters added by token completion to the right of the insertion point by the
  /// `CodeStorageDelegate`, so that the `CodeViewDelegate` can restrict the advance of the insertion point. This is
  /// only necessary on macOS and seems like a kludge.
  ///
  var tokenCompletionCharacters: Int = 0


  // MARK: Initialisers

  init(with language: LanguageConfiguration, setText: @escaping (String) -> Void) {
    self.language  = language
    self.tokeniser = Tokeniser(for: language.tokenDictionary,
                               caseInsensitiveReservedIdentifiers: language.caseInsensitiveReservedIdentifiers)
    self.setText   = setText
    super.init()
  }
  
  deinit {
    Task { [languageService] in
      try await languageService?.stop()
    }
  }


  // MARK: Updates

  /// Reinitialise the code storage delegate with a new language.
  ///
  /// - Parameter language: The new language.
  ///
  /// This implies stopping any already running language service first. We don't do anything if target language
  /// configuration equals the current one.
  ///
  func change(language: LanguageConfiguration, for codeStorage: CodeStorage) async throws {
    let currentLanguage = self.language
    guard language != currentLanguage else { return }

    try await languageService?.stop()
    self.language = language

    // If the actual language changes and not just the language service, re-tokenise the code storage.
    if currentLanguage.name != language.name {

      self.tokeniser = Tokeniser(for: language.tokenDictionary,
                                 caseInsensitiveReservedIdentifiers: language.caseInsensitiveReservedIdentifiers)
      let _ = tokenise(range: NSRange(location: 0, length: codeStorage.length), in: codeStorage)

    }
  }
  

  // MARK: Delegate methods

  func textStorage(_ textStorage: NSTextStorage,
                   willProcessEditing editedMask: TextStorageEditActions,
                   range editedRange: NSRange,
                   changeInLength delta: Int)
  {
    func messageAffectedByEditFor(line: Int) -> Bool {
      // `true` iff the affected range of each message is in its entirety before (to the left) of the `editedRange`.
      if let (range, info) = lineMap.lookup(line: line) {
        info?.messages?.messages.allSatisfy{ $0.0 + $0.1.length < editedRange.location - range.location } ?? false
      } else { false }
    }

    tokenInvalidationRange = nil
    tokenInvalidationLines = nil
    guard let codeStorage = textStorage as? CodeStorage else { return }

    // If only attributes change, the line map and syntax highlighting remains the same => nothing for us to do
    guard editedMask.contains(.editedCharacters) else { return }

    // FIXME: This (and the rest of visual debugging) needs to be rewritten to use rendering attributes.
    if visualDebugging {
      let wholeTextRange = NSRange(location: 0, length: textStorage.length)
      textStorage.removeAttribute(.backgroundColor, range: wholeTextRange)
      textStorage.removeAttribute(.underlineColor, range: wholeTextRange)
      textStorage.removeAttribute(.underlineStyle, range: wholeTextRange)
    }

    // Determine the ids of message bundles that are invalidated by this edit.
    let lines = lineMap.linesAffected(by: editedRange, changeInLength: delta)
    lastInvalidatedMessageIDs = lines.compactMap { line in
      if line == lines.first {
        if messageAffectedByEditFor(line: line) { lineMap.lookup(line: line)?.info?.messages?.id } else { nil }
      } else {
        lineMap.lookup(line: line)?.info?.messages?.id
      }
    }

    let endColumn = if let beforeLine     = lines.last,
                       let beforeLineInfo = lineMap.lookup(line: beforeLine)
                    {
                       editedRange.max - delta - beforeLineInfo.range.location
                    } else { 0 }

    lineMap.updateAfterEditing(string: textStorage.string, range: editedRange, changeInLength: delta)
    var (affectedRange: highlightingRange, lines: highlightingLines) = tokenise(range: editedRange, in: textStorage)

    processingStringReplacement = editedRange == NSRange(location: 0, length: textStorage.length)

    // If a single character was added, process token-level completion steps (and remember that we are processing a
    // one character addition).
    processingOneCharacterAddition = delta == 1 && editedRange.length == 1
    var editedRange = editedRange
    var delta       = delta
    if processingOneCharacterAddition {

      tokenCompletionCharacters = tokenCompletion(for: codeStorage, at: editedRange.location)
      if tokenCompletionCharacters > 0 {

        // Update line map with completion characters.
        lineMap.updateAfterEditing(string: textStorage.string, range: NSRange(location: editedRange.location + 1,
                                                                              length: tokenCompletionCharacters),
                                   changeInLength: tokenCompletionCharacters)

        // Adjust the editing range and delta
        editedRange.length += tokenCompletionCharacters
        delta              += tokenCompletionCharacters

        // Re-tokenise the whole lot with the completion characters included
        let extraHighlighting = tokenise(range: editedRange, in: textStorage)
        highlightingRange = highlightingRange.union(extraHighlighting.affectedRange)
        highlightingLines += extraHighlighting.lines

      }
    }

    // The range within which highlighting has to be re-rendered.
    tokenInvalidationRange = highlightingRange
    tokenInvalidationLines = highlightingLines

    if visualDebugging {
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingEditedColour, range: editedRange)
    }

    // MARK: [Note Propagating text changes into SwiftUI]
    // We need to trigger the propagation of text changes via the binding passed to the `CodeEditor` view here and *not*
    // in the `NSTextViewDelegate` or `UITextViewDelegate`. The reason for this is the composition of characters with
    // diacritics using muliple key strokes. Until the composition is complete, the already entered composing characters
    // are indicated by marked text and do *not* lead to the signaling of text changes by `NSTextViewDelegate` or
    // `UITextViewDelegate`, although they *do* alter the text storage. However, the methods of `NSTextStorageDelegate`
    // are invoked at each step of the composition process, faithfully representing the state changes of the text
    // storage.
    //
    // Why is this important? Because `CodeEditor.updateNSView(_:context:)` and `CodeEditor.updateUIView(_:context:)`
    // compare the current contents of the text binding with the current contents of the text storage to determine
    // whether the latter needs to be updated. If the text storage changes without propagating the change to the
    // binding, this check inside `CodeEditor.updateNSView(_:context:)` and `CodeEditor.updateUIView(_:context:)` will
    // suggest that the text storage needs to be overwritten by the contents of the binding, incorrectly removing any
    // entered composing characters (i.e., the marked text).
    setText(textStorage.string)

    if !skipNextChangeNotificationToLanguageService {

      // Notify language service (if attached)
      let text         = (textStorage.string as NSString).substring(with: editedRange),
          afterLine    = lineMap.lineOf(index: editedRange.max),
          lineChange   = if let afterLine,
                            let beforeLine = lines.last { afterLine - beforeLine } else { 0 },
          columnChange = if let afterLine,
                            let info = lineMap.lookup(line: afterLine)
                         {
                           editedRange.max - info.range.location - endColumn
                         } else { 0 }
      Task { [editedRange, delta] in
        try await languageService?.documentDidChange(position: editedRange.location,
                                                     changeInLength: delta,
                                                     lineChange: lineChange,
                                                     columnChange: columnChange,
                                                     newText: text)
      }
    } else { skipNextChangeNotificationToLanguageService = false }
  }
}


// MARK: -
// MARK: Location conversion

extension CodeStorageDelegate {

  /// This class serves as a location service on the basis of the line map of an encapsulated storage delegate.
  ///
  final class LineMapLocationService: LocationService {
    private weak var codeStorageDelegate: CodeStorageDelegate?

    enum ConversionError: Error {
      case lineMapUnavailable
      case locationOutOfBounds
      case lineOutOfBounds
    }

    /// Location converter on the basis of the line map of the given storage delegate.
    ///
    /// - Parameter codeStorageDelegate: The code storage delegate whose line map ought to serve as the basis for the
    ///   conversion.
    ///
    init(codeStorageDelegate: CodeStorageDelegate) {
      self.codeStorageDelegate = codeStorageDelegate
    }

    func textLocation(from location: Int) -> Result<TextLocation, Error> {
      guard let lineMap = codeStorageDelegate?.lineMap else { return .failure(ConversionError.lineMapUnavailable) }

      if let line    = lineMap.lineOf(index: location),
         let oneLine = lineMap.lookup(line: line)
      {

        return .success(TextLocation(zeroBasedLine: line, column: location - oneLine.range.location))

      } else { return .failure(ConversionError.locationOutOfBounds) }
    }

    func location(from textLocation: TextLocation) -> Result<Int, Error> {
      guard let lineMap = codeStorageDelegate?.lineMap else { return .failure(ConversionError.lineMapUnavailable) }

      if let oneLine = lineMap.lookup(line: textLocation.zeroBasedLine) {

        return .success(oneLine.range.location + textLocation.zeroBasedColumn)

      } else { return .failure(ConversionError.lineOutOfBounds) }
    }

    func length(of zeroBasedLine: Int) -> Int? { codeStorageDelegate?.lineMap.lookup(line: zeroBasedLine)?.range.length }
  }

  /// Yield a location converter for the text maintained by the present code storage delegate.
  ///
  var lineMapLocationConverter: LineMapLocationService { LineMapLocationService(codeStorageDelegate: self) }
}


// MARK: -
// MARK: Tokenisation

extension CodeStorageDelegate {

  /// Tokenise the substring of the given text storage that contains the specified lines and store tokens as part of the
  /// line information.
  /// 
  /// - Parameters:
  ///   - originalRange: The character range that contains all characters that have changed.
  ///   - textStorage: The text storage that contains the changed characters.
  /// - Returns: The range of text affected by tokenisation together with the number of lines the range spreads over.
  ///     This can be more than the `originalRange` as changes in commenting and the like might affect large portions of
  ///     text.
  ///
  /// Tokenisation happens at line granularity. Hence, the range is correspondingly extended. Moreover, tokens must not
  /// span across lines as they will always only associated with the line on which they start.
  /// 
  func tokenise(range originalRange: NSRange, in textStorage: NSTextStorage) -> (affectedRange: NSRange, lines: Int) {

    // NB: The range property of the tokens is in terms of the entire text (not just `line`).
    func tokeniseAndUpdateInfo<Tokens: Collection<Tokeniser<LanguageConfiguration.Token,
                                                              LanguageConfiguration.State>.Token>>
    (for line: Int,
     tokens: Tokens,
     commentDepth: inout Int,
     lastCommentStart: inout Int?,
     curlyBracketDepth: inout Int)
    {

      if let lineRange = lineMap.lookup(line: line)?.range {

        if visualDebugging {

          for token in tokens {
            textStorage.addAttribute(.underlineColor, value: visualDebuggingTokenColour, range: range)
            if token.range.length > 0 {
              textStorage.addAttribute(.underlineStyle,
                                       value: NSNumber(value: NSUnderlineStyle.double.rawValue),
                                       range: NSRange(location: token.range.location, length: 1))
            }
            if token.range.length > 1 {
              textStorage.addAttribute(.underlineStyle,
                                       value: NSNumber(value: NSUnderlineStyle.single.rawValue),
                                       range: NSRange(location: token.range.location + 1,
                                                      length: token.range.length - 1))
            }
          }
        }

        let localisedTokens = tokens.map{ $0.shifted(by: -lineRange.location) }
        var lineInfo         = LineInfo(commentDepthStart: commentDepth,
                                        commentDepthEnd: 0,
                                        roundBracketDiff: 0,
                                        squareBracketDiff: 0,
                                        curlyBracketDepthStart: curlyBracketDepth,
                                        curlyBracketDepthEnd: 0,
                                        tokens: localisedTokens,
                                        commentRanges: [])
        tokenLoop: for token in localisedTokens {

          switch token.token {

          case .roundBracketOpen:
            lineInfo.roundBracketDiff += 1

          case .roundBracketClose:
            lineInfo.roundBracketDiff -= 1

          case .squareBracketOpen:
            lineInfo.squareBracketDiff += 1

          case .squareBracketClose:
            lineInfo.squareBracketDiff -= 1

          case .curlyBracketOpen:
            curlyBracketDepth += 1

          case .curlyBracketClose:
            curlyBracketDepth -= 1

          case .singleLineComment:  // set comment attribute from token start token to the end of this line
            let commentStart = token.range.location
            lineInfo.commentRanges.append(NSRange(location: commentStart, length: lineRange.length - commentStart))
            break tokenLoop   // the rest of the tokens are ignored as they are commented out and we'll rescan on change

          case .nestedCommentOpen:
            if commentDepth == 0 { lastCommentStart = token.range.location }    // start of an outermost nested comment
            commentDepth += 1

          case .nestedCommentClose:
            if commentDepth > 0 {

              commentDepth -= 1

              // If we just closed an outermost nested comment, attribute the comment range
              if let start = lastCommentStart, commentDepth == 0
              {
                lineInfo.commentRanges.append(NSRange(location: start, length: token.range.max - start))
                lastCommentStart = nil
              }
            }

          default:
            break
          }
        }

        // If the line ends while we are still in an open comment, we need a comment attribute up to the end of the line
        if let start = lastCommentStart, commentDepth > 0 {

          lineInfo.commentRanges.append(NSRange(location: start, length: lineRange.length - start))
          lastCommentStart = 0

        }

        // Retain computed line information
        lineInfo.commentDepthEnd      = commentDepth
        lineInfo.curlyBracketDepthEnd = curlyBracketDepth
        lineMap.setInfoOf(line: line, to: lineInfo)
      }
    }

    guard let tokeniser = tokeniser else { return (affectedRange: originalRange, lines: 1) }

    // Extend the range to line boundaries. Because we cannot parse partial tokens, we at least need to go to word
    // boundaries, but because we have line bounded constructs like comments to the end of the line and it is easier to
    // determine the line boundaries, we use those.
    let lines = lineMap.linesContaining(range: originalRange),
        range = lineMap.charRangeOf(lines: lines)

    guard let stringRange = Range<String.Index>(range, in: textStorage.string) 
    else { return (affectedRange: originalRange, lines: lines.count) }

    // Determine the comment depth as determined by the preceeeding code. This is needed to determine the correct
    // tokeniser and to compute attribute information from the resulting tokens. NB: We need to get that info from
    // the previous line, because the line info of the current line was set to `nil` during updating the line map.
    let initialCommentDepth  = lineMap.lookup(line: lines.startIndex - 1)?.info?.commentDepthEnd ?? 0

    // Set the token attribute in range.
    let initialTokeniserState: LanguageConfiguration.State
               = initialCommentDepth > 0 ? .tokenisingComment(initialCommentDepth) : .tokenisingCode,
        tokens = textStorage
                   .string[stringRange]
                   .tokenise(with: tokeniser, state: initialTokeniserState)
                   .map{ $0.shifted(by: range.location) }       // adjust tokens to be relative to the whole `string`

    let initialCurlyBracketDepth = lineMap.lookup(line: lines.startIndex - 1)?.info?.curlyBracketDepthEnd ?? 0

    // For all lines in range, collect the tokens line by line, while keeping track of nested comments
    //
    // - `lastCommentStart` keeps track of the last start of an *outermost* nested comment.
    //
    var commentDepth      = initialCommentDepth
    var lastCommentStart  = initialCommentDepth > 0 ? lineMap.lookup(line: lines.startIndex)?.range.location : nil
    var curlyBracketDepth = initialCurlyBracketDepth
    var remainingTokens   = tokens
    for line in lines {

      guard let lineRange = lineMap.lookup(line: line)?.range else { continue }
      let thisLinesTokens = remainingTokens.prefix(while: { $0.range.location < lineRange.max })
      tokeniseAndUpdateInfo(for: line,
                            tokens: thisLinesTokens,
                            commentDepth: &commentDepth,
                            lastCommentStart: &lastCommentStart,
                            curlyBracketDepth: &curlyBracketDepth)
      remainingTokens.removeFirst(thisLinesTokens.count)

    }

    // Continue to re-process line by line until there is no longer a change in the comment depth before and after
    // re-processing
    //
    var currentLine       = lines.endIndex
    var highlightingRange = range
    var highlightingLines = lines.count
    trailingLineLoop: while currentLine < lineMap.lines.count {

      if let lineEntry      = lineMap.lookup(line: currentLine),
         let lineEntryRange = Range<String.Index>(lineEntry.range, in: textStorage.string)
      {

        // If this line has got a line info entry and the expected comment depth at the start of the line matches
        // the current comment depth, we reached the end of the range of lines affected by this edit => break the loop
        if let depth = lineEntry.info?.commentDepthStart, depth == commentDepth { break trailingLineLoop }

        // Re-tokenise line
        let initialTokeniserState: LanguageConfiguration.State
                   = commentDepth > 0 ? .tokenisingComment(commentDepth) : .tokenisingCode,
            tokens = textStorage
                       .string[lineEntryRange]
                       .tokenise(with: tokeniser, state: initialTokeniserState)
                       .map{ $0.shifted(by: lineEntry.range.location) } // adjust tokens to be relative to the whole `string`

        // Collect the tokens and update line info
        tokeniseAndUpdateInfo(for: currentLine,
                              tokens: tokens,
                              commentDepth: &commentDepth,
                              lastCommentStart: &lastCommentStart,
                              curlyBracketDepth: &curlyBracketDepth)

        // Keep track of the trailing range to report back to the caller.
        highlightingRange = NSUnionRange(highlightingRange, lineEntry.range)
        highlightingLines += 1

      }
      currentLine += 1
    }

    requestSemanticTokens(for: lines, in: textStorage)

    if visualDebugging {
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingTrailingColour, range: highlightingRange)
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingLinesColour, range: range)
    }

    return (affectedRange: highlightingRange, lines: highlightingLines)
  }

  /// Query semantic tokens for the given lines from the language service (if available) and merge them into the token
  /// information for those lines (maintained in the line map),
  ///
  /// - Parameters:
  ///     lines: The lines for which semantic token information is requested.
  ///     textStorage: The text storage whose contents is being tokenised.
  ///
  func requestSemanticTokens(for lines: Range<Int>, in textStorage: NSTextStorage) {
    guard let firstLine = lines.first else { return }

    Task {
      do {
        if let semanticTokens = try await languageService?.tokens(for: lines) {

          guard lines.count == semanticTokens.count else {
            logger.trace("Language service returned an array of incorrect length; expected \(lines.count), but got \(semanticTokens.count)")
            return
          }

          // We need to avoid concurrent write access to the line map; hence, use the main actor.
          Task { @MainActor in

            // Merge the semantic tokens into the syntactic tokens per line
            for i in 0..<lines.count {
              merge(semanticTokens: semanticTokens[i], into: firstLine + i)
            }

            // Request redrawing for those lines
            if let textStorageObserver = textStorage.textStorageObserver {
              let range = lineMap.charRangeOf(lines: lines)
              textStorageObserver.processEditing(for: textStorage,
                                                 edited: .editedAttributes,
                                                 range: range,
                                                 changeInLength: 0,
                                                 invalidatedRange: NSRange(location: 0, length: textStorage.string.count))
                                                                   // ^^If we don't invalidate the whole text, we
                                                                   // somehow lose highlighting for everything outside
                                                                   // of the invalidated range.
            }
          }

        }
      } catch let error { logger.trace("Failed to get semantic tokens for line range \(lines): \(error.localizedDescription)") }
    }
  }

  /// Merge semantic token information for one line into the line map.
  ///
  /// - Parameters:
  ///   - semanticTokens: The semntic tokens to merge.
  ///   - line: The line on which the tokens are located.
  ///
  /// NB: Currently, we only enrich the information of tokens that are already present as syntactic tokens.
  ///
  private func merge(semanticTokens: [(token: LanguageConfiguration.Token, range: NSRange)], into line: Int) {
    guard var info = lineMap.lookup(line: line)?.info,
          !semanticTokens.isEmpty       // Short-cut if there are no semantic tokens
    else { return }

    var remainingSemanticTokens = semanticTokens
    var tokens                  = info.tokens
    for i in 0..<tokens.count {

      let token = tokens[i]
      while let semanticToken = remainingSemanticTokens.first,
            semanticToken.range.location <= token.range.location
      {
        remainingSemanticTokens.removeFirst()

        // We enrich identifier and operator tokens if the semantic token is an identifier, operator, or keyword.
        if semanticToken.range == token.range
            && (token.token.isIdentifier || token.token.isOperator)
            && (semanticToken.token.isIdentifier || semanticToken.token.isOperator || semanticToken.token == .keyword)
        {
          tokens[i] = LanguageConfiguration.Tokeniser.Token(token: semanticToken.token, range: token.range)
        }
      }
    }

    // Store updated token array
    info.tokens = tokens
    lineMap.setInfoOf(line: line, to: info)
  }
}


// MARK: -
// MARK: Token completion

extension CodeStorageDelegate {

  /// Handle token completion actions after a single character was inserted.
  /// 
  /// - Parameters:
  ///   - codeStorage: The code storage where the edit action occured.
  ///   - index: The location within the text storage where the single character was inserted.
  /// - Returns: The number of characters added.
  ///
  /// This function only adds characters right after `index`. (This is crucial so that the caller knows where to adjust
  /// the line map and tokenisation.)
  ///
  func tokenCompletion(for codeStorage: CodeStorage, at index: Int) -> Int {

    /// If the given token is an opening bracket, return the lexeme of its matching closing bracket.
    ///
    func matchingLexemeForOpeningBracket(_ token: LanguageConfiguration.Token) -> String? {
      if token.isOpenBracket, let matching = token.matchingBracket, let lexeme = language.lexeme(of: matching)
      {
        return lexeme
      } else {
        return nil
      }
    }

    /// Determine whether the ranges of the two tokens are overlapping.
    ///
    func overlapping(_ previousToken: LanguageConfiguration.Tokeniser.Token,
                     _ currentToken: LanguageConfiguration.Tokeniser.Token?)
    -> Bool
    {
      if let currentToken = currentToken {
        return NSIntersectionRange(previousToken.range, currentToken.range).length != 0
      } else { return false }
    }


    let string             = codeStorage.string,
        char               = string.utf16[string.index(string.startIndex, offsetBy: index)],
        previousTypedToken = lastTypedToken,
        currentTypedToken  = codeStorage.tokenOnly(at: index)

    lastTypedToken = currentTypedToken    // this is the default outcome, unless explicitly overridden below

    // The just entered character is right after the previous token and it doesn't belong to a token overlapping with
    // the previous token
    if let previousToken = previousTypedToken, previousToken.range.max == index,
       !overlapping(previousToken, currentTypedToken) {

      let completingString: String?

      // If the previous token was an opening bracket, we may have to autocomplete by inserting a matching closing
      // bracket
      if let matchingPreviousLexeme = matchingLexemeForOpeningBracket(previousToken.token)
      {

        if let currentToken = currentTypedToken {

          if currentToken.token == previousToken.token.matchingBracket {

            // The current token is a matching closing bracket for the opening bracket of the last token => nothing to do
            completingString = nil

          } else if let matchingCurrentLexeme = matchingLexemeForOpeningBracket(currentToken.token) {

            // The current token is another opening bracket => insert matching closing for the current and previous
            // opening bracket
            completingString = matchingCurrentLexeme + matchingPreviousLexeme

          } else {

            // Insertion of an unrelated or non-bracket token => just complete the previous opening bracket
            completingString = matchingPreviousLexeme

          }

        } else {

          // If a opening curly brace or nested comment bracket is followed by a line break, add another line break
          // before the matching closing bracket.
          if let unichar = Unicode.Scalar(char),
             CharacterSet.newlines.contains(unichar),
             previousToken.token == .curlyBracketOpen || previousToken.token == .nestedCommentOpen
          {

            // Insertion of a newline after a curly bracket => complete the previous opening bracket prefixed with an extra newline
            completingString = String(unichar) + matchingPreviousLexeme

          } else {

          // Insertion of a character that doesn't complete a token => just complete the previous opening bracket
          completingString = matchingPreviousLexeme

          }
        }

      } else { completingString = nil }

      // Insert completion, if any
      if let string = completingString {

        lastTypedToken = nil    // A completion renders the last token void
        codeStorage.replaceCharacters(in: NSRange(location: index + 1, length: 0), with: string)

      }
      return completingString?.utf16.count ?? 0

    } else { return 0 }
  }
}


// MARK: -
// MARK: Messages

extension CodeStorageDelegate {

  /// Add the given message to the line info of the line where the message is located.
  ///
  /// - Parameter message: The message to add.
  /// - Returns: The message bundle to which the message was added, or `nil` if the line for which the message is
  ///     intended doesn't exist.
  ///
  /// NB: Ignores messages for lines that do not exist in the line map. A message may not be added to multiple lines.
  ///
  func add(message: TextLocated<Message>) -> LineInfo.MessageBundle? {
    guard var info = lineMap.lookup(line: message.location.zeroBasedLine)?.info else { return nil }

    let columnMessage = (message.location.zeroBasedColumn, message.entity)
    if info.messages != nil {

      // Add a message to an existing message bundle for this line
      info.messages?.add(message: columnMessage)

    } else {

      // Create a new message bundle for this line with the new message
      info.messages = LineInfo.MessageBundle(messages: [columnMessage])

    }
    lineMap.setInfoOf(line: message.location.zeroBasedLine, to: info)
    return info.messages
  }

  /// Remove the given message from the line info in which it is located. This function is quite expensive.
  ///
  /// - Parameter message: The message to remove.
  /// - Returns: The updated message bundle from which the message was removed together with the line where it occured,
  ///     or `nil` if the message occurs in no line bundle.
  ///
  /// NB: Ignores messages that do not exist in the line map. It is considered an error if a message exists at multiple
  ///     lines. In this case, the occurences at the first such line will be used.
  ///
  func remove(message: Message) -> (LineInfo.MessageBundle, Int)? {

    for line in lineMap.lines.indices {
      if var info = lineMap.lines[line].info {

        info.messages?.remove(message: message)
        lineMap.setInfoOf(line: line, to: info)
        if let messages = info.messages { return (messages, line) } else { return nil }

      }
    }
    return nil
  }

  /// Returns the message bundle associated with the given line if it exists.
  ///
  /// - Parameter line: The line for which we want to know the associated message bundle.
  /// - Returns: The message bundle associated with the given line or `nil`.
  ///
  /// NB: In case that the line does not exist, an empty array is returned.
  ///
  func messages(at line: Int) -> LineInfo.MessageBundle? { return lineMap.lookup(line: line)?.info?.messages }

  /// Remove all messages associated with a given line.
  ///
  /// - Parameter line: The line whose messages ought ot be removed.
  ///
  func removeMessages(at line: Int) {
    guard var info = lineMap.lookup(line: line)?.info else  { return }

    info.messages = nil
    lineMap.setInfoOf(line: line, to: info)
  }
}
