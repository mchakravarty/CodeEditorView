//
//  CodeStorageDelegate.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/09/2020.
//
//  'NSTextStorageDelegate' for code views compute, collect, store, and update additional information about the text
//  stored in the 'NSTextStorage' that they serve. This is needed to quickly navigate the text (e.g., at which character
//  position does a particular line start) and to support code-specific rendering (e.g., syntax highlighting).

// FIXME: the aliases ought to be moved to some central place for os impedance matching
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


// MARK: -
// MARK: Visual debugging support

// FIXME: It should be possible to enable this via a defaults setting.
private let visualDebugging               = false
private let visualDebuggingEditedColour   = Color(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.3)
private let visualDebuggingLinesColour    = Color(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.3)
private let visualDebuggingTrailingColour = Color(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.3)
private let visualDebuggingTokenColour    = Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)


// MARK: -
// MARK: Tokens

// Custom token attributes
//
extension NSAttributedString.Key {

  /// Custom attribute marking comment ranges.
  ///
  static let comment = NSAttributedString.Key("comment")

  /// Custom attribute marking lexical tokens.
  ///
  static let token = NSAttributedString.Key("token")
}

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
  var commentDepthStart: Int   // nesting depth for nested comments at the start of this line
  var commentDepthEnd:   Int   // nesting depth for nested comments at the end of this line
  var roundBracketDiff:  Int   // increase or decrease of the nesting level of round brackets on this line
  var squareBracketDiff: Int   // increase or decrease of the nesting level of square brackets on this line
  var curlyBracketDiff:  Int   // increase or decrease of the nesting level of curly brackets on this line
}


// MARK: -
// MARK: Delegate class

class CodeStorageDelegate: NSObject, NSTextStorageDelegate {

  private let language:  LanguageConfiguration
  private let tokeniser: Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>? // cache the tokeniser

  private(set) var lineMap = LineMap<LineInfo>(string: "")

  /// If the last text change was a one-character addition, which completed a token, then that token is remembered here
  /// together with the position of its *last* character (the completing one) until the next text change.
  ///
  private var lastTypedToken: (type: LanguageConfiguration.Token, index: Int)?

  /// Flag that indicates that the current editing round is for a one-character addition to the text. This property
  /// needs to be determined before attribute fixing and the like.
  ///
  private var processingOneCharacterEdit: Bool?

  init(with language: LanguageConfiguration) {
    self.language  = language
    self.tokeniser = NSMutableAttributedString.tokeniser(for: language.tokenDictionary, with: .tokenBody)
    super.init()
  }

  func textStorage(_ textStorage: NSTextStorage,
                   willProcessEditing editedMask: TextStorageEditActions,
                   range editedRange: NSRange,
                   changeInLength delta: Int)
  {
    processingOneCharacterEdit = delta == 1 && editedRange.length == 1
  }

  // NB: The choice of `didProcessEditing` versus `willProcessEditing` is crucial on macOS. The reason is that
  //     the text storage performs "attribute fixing" between `willProcessEditing` and `didProcessEditing`. If we
  //     modify attributes outside of `editedRange` (which we often do), then this triggers the movement of the
  //     current selection to the end of the entire text.
  //
  //     By doing the highlighting work *after* attribute fixing, we avoid affecting the selection. However, it now
  //     becomes *very* important to (a) refrain from any character changes and (b) from any attribute changes that
  //     result in attributes that need to be fixed; otherwise, we end up with an inconsistent attributed string.
  //     (In particular, changing the font attribute at this point is potentially dangerous.)
  func textStorage(_ textStorage: NSTextStorage,
                   didProcessEditing editedMask: TextStorageEditActions,
                   range editedRange: NSRange,  // Apple docs are incorrect here: this is the range *after* editing
                   changeInLength delta: Int)
  {
    // If only attributes change, the line map and syntax highlighting remains the same => nothing for us to do
    guard editedMask.contains(.editedCharacters) else { return }

    if visualDebugging {
      let wholeTextRange = NSRange(location: 0, length: textStorage.length)
      textStorage.removeAttribute(.backgroundColor, range: wholeTextRange)
      textStorage.removeAttribute(.underlineColor, range: wholeTextRange)
      textStorage.removeAttribute(.underlineStyle, range: wholeTextRange)
    }

    lineMap.updateAfterEditing(string: textStorage.string, range: editedRange, changeInLength: delta)
    tokeniseAttributesFor(range: editedRange, in: textStorage)

    if visualDebugging {
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingEditedColour, range: editedRange)
    }

    // If a single character was added, process token-level completion steps.
    if delta == 1 && processingOneCharacterEdit == true {
      tokenCompletion(for: textStorage, at: editedRange.location)
    }
    processingOneCharacterEdit = nil
  }
}


// MARK: -
// MARK: Tokenisation

extension CodeStorageDelegate {

  /// Tokenise the substring of the given text storage that contains the specified lines and set token attributes as
  /// needed.
  ///
  /// - Parameters:
  ///   - originalRange: The character range that contains all characters that have changed.
  ///   - textStorage: The text storage that contains the changed characters.
  ///
  /// Tokenisation happens at line granularity. Hence, the range is correspondingly extended.
  ///
  func tokeniseAttributesFor(range originalRange: NSRange, in textStorage: NSTextStorage) {

    func tokeniseAndUpdateInfo(for line: Int, commentDepth: inout Int, lastCommentStart: inout Int?) {

      if let lineRange = lineMap.lookup(line: line)?.range {

        // Remove any existing `.comment` attribute on this line
        textStorage.removeAttribute(.comment, range: lineRange)

        // Collect all tokens on this line.
        // (NB: In the block, we are not supposed to mutate outside the attribute range; hence, we only collect tokens.)
        var tokens = Array<(token: LanguageConfiguration.Token, range: NSRange)>()
        textStorage.enumerateTokens(in: lineRange){ (tokenValue, range, _) in

          tokens.append((token: tokenValue, range: range))

          if visualDebugging {

            textStorage.addAttribute(.underlineColor, value: visualDebuggingTokenColour, range: range)
            if range.length > 0 {
              textStorage.addAttribute(.underlineStyle,
                                       value: NSNumber(value: NSUnderlineStyle.double.rawValue),
                                       range: NSRange(location: range.location, length: 1))
            }
            if range.length > 1 {
              textStorage.addAttribute(.underlineStyle,
                                       value: NSNumber(value: NSUnderlineStyle.single.rawValue),
                                       range: NSRange(location: range.location + 1, length: range.length - 1))
            }
          }
        }

        var lineInfo = LineInfo(commentDepthStart: commentDepth,
                                commentDepthEnd: 0,
                                roundBracketDiff: 0,
                                squareBracketDiff: 0,
                                curlyBracketDiff: 0)
        tokenLoop: for token in tokens {

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
            lineInfo.curlyBracketDiff += 1

          case .curlyBracketClose:
            lineInfo.curlyBracketDiff -= 1

          case .singleLineComment:  // set comment attribute from token start token to the end of this line
            let commentStart = token.range.location,
                commentRange = NSRange(location: commentStart, length: NSMaxRange(lineRange) - commentStart)
            textStorage.addAttribute(.comment, value: CommentStyle.singleLineComment, range: commentRange)
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
                textStorage.addAttribute(.comment,
                                         value: CommentStyle.nestedComment,
                                         range: NSRange(location: start, length: NSMaxRange(token.range) - start))
                lastCommentStart = nil
              }
            }

          default:
            break
          }
        }

        // If the line ends while we are still in an open comment, we need a comment attribute up to the end of the line
        if let start = lastCommentStart, commentDepth > 0 {

          textStorage.addAttribute(.comment,
                                   value: CommentStyle.nestedComment,
                                   range: NSRange(location: start, length: NSMaxRange(lineRange) - start))

        }

        // Retain computed line information
        lineInfo.commentDepthEnd = commentDepth
        lineMap.setInfoOf(line: line, to: lineInfo)
      }
    }

    guard let tokeniser = tokeniser else { return }

    // Extend the range to line boundaries. Because we cannot parse partial tokens, we at least need to go to word
    // boundaries, but because we have line bounded constructs like comments to the end of the line and it is easier to
    // determine the line boundaries, we use those.
    let lines = lineMap.linesContaining(range: originalRange),
        range = lineMap.charRangeOf(lines: lines)

    // Determine the comment depth as determined by the preceeeding code. This is needed to determine the correct
    // tokeniser and to compute attribute information from the resulting tokens. NB: We need to get that info from
    // the previous line, because the line info of the current line was set to `nil` during updating the line map.
    let initialCommentDepth  = lineMap.lookup(line: lines.startIndex - 1)?.info?.commentDepthEnd ?? 0

    // Set the token attribute in range.
    let initialTokeniserState: LanguageConfiguration.State
      = initialCommentDepth > 0 ? .tokenisingComment(initialCommentDepth) : .tokenisingCode
    textStorage.tokeniseAndSetTokenAttribute(attribute: .token,
                                             with: tokeniser,
                                             state: initialTokeniserState,
                                             in: range)

    // For all lines in range, collect the tokens line by line, while keeping track of nested comments
    //
    // - `lastCommentStart` keeps track of the last start of an *outermost* nested comment.
    //
    var commentDepth     = initialCommentDepth
    var lastCommentStart = initialCommentDepth > 0 ? lineMap.lookup(line: lines.startIndex)?.range.location : nil
    for line in lines {
      tokeniseAndUpdateInfo(for: line, commentDepth: &commentDepth, lastCommentStart: &lastCommentStart)
    }

    // Continue to re-process line by line until there is no longer a change in the comment depth before and after
    // re-processing
    //
    var currentLine       = lines.endIndex
    var highlightingRange = range
    trailingLineLoop: while currentLine < lineMap.lines.count {

      if let lineEntry = lineMap.lookup(line: currentLine) {

        // If this line has got a line info entry and the expected comment depth at the start of the line matches
        // the current comment depth, we reached the end of the range of lines affected by this edit => break the loop
        if let depth = lineEntry.info?.commentDepthStart, depth == commentDepth { break trailingLineLoop }

        // Re-tokenise line
        let initialTokeniserState: LanguageConfiguration.State
          = commentDepth > 0 ? .tokenisingComment(commentDepth) : .tokenisingCode
        textStorage.tokeniseAndSetTokenAttribute(attribute: .token,
                                                 with: tokeniser,
                                                 state: initialTokeniserState,
                                                 in: lineEntry.range)

        // Collect the tokens and update line info
        tokeniseAndUpdateInfo(for: currentLine, commentDepth: &commentDepth, lastCommentStart: &lastCommentStart)

        // The currently processed line needs to be highlighted, too
        highlightingRange = NSUnionRange(highlightingRange, lineEntry.range)

      }
      currentLine += 1
    }

    if visualDebugging {
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingTrailingColour, range: highlightingRange)
      textStorage.addAttribute(.backgroundColor, value: visualDebuggingLinesColour, range: range)
    }

    fixHighlightingAttributes(range: highlightingRange, in: textStorage)
  }

  /// Based on the token attributes, set the highlighting attributes of the characters in the given line range.
  ///
  func fixHighlightingAttributes(range: NSRange, in textStorage: NSTextStorage) {

    // FIXME: colours need to come from a theme
    textStorage.addAttribute(.foregroundColor, value: labelColor, range: range)
    textStorage.enumerateTokens(in: range){ (value, attrRange, _) in
      
      if value == .string { textStorage.addAttribute(.foregroundColor, value: Color.systemGreen, range: attrRange) }
    }
    textStorage.enumerateAttribute(.comment, in: range){ (optionalValue, attrRange, _) in

      if optionalValue != nil { textStorage.addAttribute(.foregroundColor, value: Color.darkGray, range: attrRange) }
    }
  }
}


// MARK: -
// MARK: Completion

extension CodeStorageDelegate {

  /// Handle token completion actions after a single character was inserted.
  ///
  /// - Parameters:
  ///   - textStorage: The text storage where the edit action occured.
  ///   - index: The location within the text storage where the single chracter was inserted.
  ///
  /// Any change to the `textStorage` is deferred, so that this function can also be used in the middle of an
  /// in-progress, but not yet completed edit.
  ///
  func tokenCompletion(for textStorage: NSTextStorage, at index: Int) {

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

    let string             = textStorage.string,
        char               = string.utf16[string.index(string.startIndex, offsetBy: index)],
        previousTypedToken = lastTypedToken,
        currentTypedToken  : (type: LanguageConfiguration.Token, index: Int)?

    // Determine the token (if any) that the right now inserted character belongs to
    if let token = textStorage.token(at: index) { currentTypedToken = (type: token.type, index: index) }
    else { currentTypedToken = nil }

    lastTypedToken = currentTypedToken    // this is the default outcome, unless explicitly overridden below

    // The just entered character is right after the previous token
    if let previousToken = previousTypedToken, previousToken.index + 1 == index {

      let completingString: String?

      // If the previous token was an opening bracket, we may have to autocomplete by inserting a matching closing
      // bracket
      if let matchingPreviousLexeme = matchingLexemeForOpeningBracket(previousToken.type)
      {

        if let currentToken = currentTypedToken {

          if currentToken.type == previousToken.type.matchingBracket {

            // The current token is a matching closing bracket for the opening bracket of the last token => nothing to do
            completingString = nil

          } else if let matchingCurrentLexeme = matchingLexemeForOpeningBracket(currentToken.type) {

            // The current token is another opening bracket => insert matching closing for the current and previous
            // opening bracket
            completingString = matchingCurrentLexeme + matchingPreviousLexeme

          } else {

            // Insertion of a unrelated or non-bracket token => just complete the previous opening bracket
            completingString = matchingPreviousLexeme

          }

        } else {

          if let unichar = Unicode.Scalar(char),
             CharacterSet.newlines.contains(unichar),
             previousToken.type == .curlyBracketOpen
          {

            // Insertion of a newline after a curly bracket => complete the previous opening bracket prefixed with an extra newline
            completingString = String(unichar) + matchingPreviousLexeme

          } else {

          // Insertion of a character that doesn't complete a token => just complete the previous opening bracket
          completingString = matchingPreviousLexeme

          }
        }

      } else { completingString = nil }

      // Defer inserting the completion
      if let string = completingString {

        lastTypedToken = nil    // A completion renders the last token void
        cursorInsert(string: string, at: index + 1, in: textStorage)

      }

    }
  }
}


// MARK: -
// MARK: Inserting text

extension CodeStorageDelegate {

  /// Insert the given string, such that it safe in an ongoing insertion cycle and does leaves the cursor (insertion
  /// point) in place if the insertion is at the location of the insertion point.
  ///
  func cursorInsert(string: String, at index: Int, in textStorage: NSTextStorage) {

    Dispatch.DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(10)){

      #if os(iOS)

      textStorage.replaceCharacters(in: NSRange(location: index, length: 0), with: string)

      #elseif os(macOS)

      // Collect the text views, where we insert at the insertion point
      var affectedTextViews: [NSTextView] = []
      for layoutManager in textStorage.layoutManagers {
        for textContainer in layoutManager.textContainers {

          if let textView = textContainer.textView, textView.selectedRange() == NSRange(location: index, length: 0) {
            affectedTextViews.append(textView)
          }
        }
      }

      textStorage.replaceCharacters(in: NSRange(location: index, length: 0), with: string)

      // Reset the insertion point to the original (pre-insertion) position (as it will move after the inserted text on
      // macOS otherwise)
      for textView in affectedTextViews { textView.setSelectedRange(NSRange(location: index, length: 0)) }

      #endif
    }
  }
}
