//
//  LanguageService.swift
//  
//
//  Created by Manuel M T Chakravarty on 10/01/2023.
//
//  This file defines the interface for external services (such as an LSP server) to provide language-specific
//  syntactic and semantic information to the code editor for a single file. It uses `Combine` for the asynchronous
//  communication between information providers and the code editor, where necessary.
//
//  An instance of a language service is specific to a single file. Hence, locations etc are always relative to the file
//  associated with the used language service.

import SwiftUI
import Combine


/// Provider of document-specific location information for a language service.
///
public protocol LocationService: LocationConverter {

  /// Yields the length of the given line.
  ///
  /// - Parameter line: The line of which we want to know the length, starting from 0.
  /// - Returns: The length (number of characters) of the given line, including any trainling newline character, or
  ///     `nil` if the line does not exist.
  ///
  func length(of line: Int) -> Int?
}

/// Function that instantiates a language service from a location converter.
///
public typealias LanguageServiceBuilder = (LocationService) -> LanguageService

/// Indicates the reason for querying code completions.
///  
public enum CompletionTriggerReason {

  /// Completion was triggered by typing a character of an identifier or by explicitly requesting completion.
  ///
  case standard

  /// Completion was triggered by the given trigger character.
  ///
  case character(Character)

  /// Completion was re-triggered to refine an incomplete completion list (after an additional character has been
  /// provided).
  case incomplete
}

/// A set of code completions for a specific code position.
///
public struct Completions {
  
  /// A single completion item.
  ///
  public struct Completion: Identifiable {
    
    /// Unique identifier in the current list of completions that remains stable during narrowing down and widening
    /// the list of completions.
    ///
    public let id: Int

    /// The view representing this completion in the completion selection list, after passing its selection status.
    ///
    public let rowView: (Bool) -> any View

    /// The view representing the documentation for this completion.
    ///
    public let documentationView: any View

    /// Whether this item ought to be selected in the list of possible completions. (Only one completion in a list of
    /// completions ought to have this flag set.)
    ///
    public let selected: Bool

    /// String to use when sorting completions.
    ///
    public let sortText: String

    /// String to use when filtering completions; e.g., upon further user input.
    ///
    public let filterText: String

    /// String to insert when this completion gets chosen. It may contain placeholders.
    ///
    public let insertText: String

    /// The range of the characters that are to be replaced by this completion if available.
    ///
    public let insertRange: NSRange?

    /// Characters that commit to this completion when typed while the completion is selected.
    ///
    public let commitCharacters: [Character]

    public init(id: Int,
                rowView: @escaping (Bool) -> any View,
                documentationView: any View,
                selected: Bool,
                sortText: String,
                filterText: String,
                insertText: String,
                insertRange: NSRange?,
                commitCharacters: [Character])
    {
      self.id                = id
      self.rowView           = rowView
      self.documentationView = documentationView
      self.selected          = selected
      self.sortText          = sortText
      self.filterText        = filterText
      self.insertText        = insertText
      self.insertRange       = insertRange
      self.commitCharacters  = commitCharacters
    }
  }

  /// Whether more code completions are possible at the code position in question. If so, the completions ought to be
  /// queried again once further user input is available.
  ///
  public let isIncomplete: Bool

  /// Suggested code completions at the code position in questions.
  ///
  public var items: [Completion]
  
  /// Yield a set of code completions for a specific code position.
  ///
  /// - Parameters:
  ///   - isIncomplete: Whether more code completions are possible at the code position in question.
  ///   - items: Suggested code completions.
  ///
  public init(isIncomplete: Bool, items: [Completions.Completion]) {
    self.isIncomplete = isIncomplete
    self.items        = items
  }
  
  /// An empty set of completions.
  ///
  public static var none: Completions { Completions(isIncomplete: false, items: []) }
}

extension Completions.Completion: Comparable {

  public static func == (lhs: Completions.Completion, rhs: Completions.Completion) -> Bool {
    lhs.sortText == lhs.sortText
  }

  public static func < (lhs: Completions.Completion, rhs: Completions.Completion) -> Bool {
    lhs.sortText < lhs.sortText
  }
}



/// Determines the capabilities and endpoints for language-dependent external services, such as an LSP server.
///
public protocol LanguageService {

  // MARK: Document synchronisation
  
  /// Notify the language service of a document change.
  /// 
  /// - Parameters:
  ///   - changeLocation: The location at which the change originates.
  ///   - delta: The change of the document length.
  ///   - deltaLine: The change of the number of lines.
  ///   - deltaColumn: The change of the column position on the last line of the changed text.
  ///   - text: The text at `changeLocation` after the change.
  ///
  func documentDidChange(position changeLocation: Int,
                         changeInLength delta: Int,
                         lineChange deltaLine: Int,
                         columnChange deltaColumn: Int,
                         newText text: String) async throws

  /// Notify the language service that the document gets closed and the language service is no longer needed.
  ///
  /// NB: After this call, no functions from the language service may be used anymore.
  ///
  func closeDocument() async throws


  // MARK: Diagnostics

  /// Notifies the code editor about a new set of diagnoistic messages. A new set replaces the previous set (merging
  /// happens server-side, not client-side).
  ///
  var diagnostics: CurrentValueSubject<Set<TextLocated<Message>>, Never> { get }


  // MARK: Code completion

  /// Characters that are not valid inside identifiers, but should trigger code completion.
  ///
  var completionTriggerCharacters: CurrentValueSubject<[Character], Never> { get }
  
  /// Yield a set of completions at the given editing position
  ///
  /// - Parameters:
  ///   - location: The text location for which completions are to be determined.
  ///   - reason: The trigger that prompted this invocation.
  /// - Returns: A possible incomplete list of completions for the given `location`.
  /// 
  func completions(at location: Int, reason: CompletionTriggerReason) async throws -> Completions


  // MARK: Semantic tokens

  /// Requests semantic token information for all tokens in the given line range.
  ///
  /// - Parameter lineRange: The lines whose semantic token information is being requested. The line count is zero-based.
  /// - Returns: Semantic tokens together with their line-relative character range divided up per line. The first
  ///     subarray contains the semantic tokens for the first line of `lineRange` and so on.
  ///
  /// The number of elements of the result is the same as the number of lines in the `lineRange`.
  ///
  func tokens(for lineRange: Range<Int>) async throws -> [[(token: LanguageConfiguration.Token, range: NSRange)]]


  // MARK: Entity information

  /// Yields an info popover for the given location in the file associated with the current language service.
  ///
  /// - Parameter location: Index position in the associated textual representation of the code.
  /// - Returns: If semantic infotmation is available for the provided location, a view displaying that information is
  ///   being returned. Optionally, the view may be accompanied by the character range to which the returned information
  ///   pertains.
  ///
  ///   In case there is an error, such as an invalid location, the function is expected to throw. However, if there is
  ///   simply no extra information available for the given location, the function simply returns `nil`.
  ///
  func info(at location: Int) async throws -> (view: any View, anchor: NSRange?)?


  // MARK: Developer support
  
  /// Render the capabilities of the underlying language service.
  ///
  /// - Returns: A view rendering the capabilities of the underlying language service.
  ///
  /// The information and its representation is dependent on the nature of the underlying language service and, in
  /// general, not fit for automatic interpretation.
  ///
  func capabilities() async throws -> (any View)?
}
