//
//  CodeActions.swift
//  
//
//  Created by Manuel M T Chakravarty on 31/01/2023.
//

import Combine
import SwiftUI
import os

import LanguageSupport


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "CodeActions")


#if os(iOS) || os(visionOS)

// MARK: -
// MARK: UIKit version

extension CodeView {

  // TODO: Code actions still need to be implemented for iOS
  func infoAction() {
  }
}


#elseif os(macOS)

// MARK: -
// MARK: AppKit version

// MARK: Code info support

/// Popover used to display the result of an info code query.
///
final class InfoPopover: NSPopover {

  /// Create an info popover with the given view displaying the code info.
  ///
  /// - Parameter view: the view displaying the queried code information.
  ///
  init(displaying view: any View, width: CGFloat) {
    super.init()
    let rootView = ScrollView(.vertical){ AnyView(view).padding() }
                     .frame(width: width, alignment: .topLeading)
    contentViewController = NSHostingController(rootView: rootView)
    contentViewController?.preferredContentSize = CGSize(width: width, height: width * 1.1)
    behavior = .transient
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension CodeView {

  /// Retain and display the given info popover.
  ///
  /// - Parameters:
  ///   - infoPopover: The new info popover to be displayed.
  ///   - range: The range of characters that the popover ought to refer to.
  ///
  @MainActor
  func show(infoPopover: InfoPopover, for range: NSRange) {

    // If there is already a popover, close it first.
    self.infoPopover?.close()

    self.infoPopover = infoPopover

    let screenRect         = firstRect(forCharacterRange: range, actualRange: nil),
        nonEmptyScreenRect = NSRect(origin: screenRect.origin, size: CGSize(width: 1, height: 1)),
        windowRect         = window!.convertFromScreen(nonEmptyScreenRect)

    infoPopover.show(relativeTo: convert(windowRect, from: nil), of: self, preferredEdge: .maxY)
  }

  func infoAction() {
    guard let languageService = optLanguageService else { return }

    let width = min((window?.frame.width ?? 250) * 0.75, 500)

    let range = selectedRange()
    Task {
      do {
        if let info = try await languageService.info(at: range.location) {

          show(infoPopover: InfoPopover(displaying: info.view, width: width), for: info.anchor ?? range)

        }
      } catch let error { logger.trace("Info action failed: \(error.localizedDescription)") }
    }
  }
}


// MARK: Completions support

/// The various operations that arise through the user interacting with the completion panel.
///
public enum CompletionProgress {

  /// Cancel code completion (e.g., user pressed ESC).
  ///
  case cancel

  /// Completion selected and the range it replaces if available.
  ///
  case completion(String, NSRange?)

  /// Addtional keystroke to refine the search.
  ///
  case input(NSEvent)
}

/// Panel used to display completions.
///
final class CompletionPanel: NSPanel {

  struct CompletionView: View {
    let completions: Completions

    @ObservedObject var selection: ObservableSelection

    @FocusState private var isFocused: Bool

    @ViewBuilder
    var completionsList: some View {

      if completions.items.isEmpty { Text("No Completions").padding() }
      else {
        List(completions.items, selection: $selection.selection) { item in
          AnyView(item.rowView(selection.selection == item.id))
            .lineLimit(1)
            .truncationMode(.middle)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
        }
      }
    }

    var body: some View {
      Group {
        if completions.items.isEmpty {

          Text("No Completions")
            .focusable(true)
            .focusEffectDisabled()
            .frame(width: 200, height: 50)
            .background(Color(nsColor: .windowBackgroundColor))
            .focused($isFocused)

        } else {

          VStack(alignment: .leading, spacing: 0) {

            completionsList
              .focused($isFocused)

            Divider()
              .overlay(.gray.opacity(0.5))
              .frame(height: 0.5)

            if let selectedCompletion = (completions.items.first{ $0.id == selection.selection }) {
              ScrollView {
                HStack {
                  AnyView(selectedCompletion.documentationView)
                  Spacer()
                }
                .padding([.top, .bottom], 2)
              }
              .padding([.leading], 8)
              .frame(maxWidth: .infinity, minHeight: 100)
            }

          }
          .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: 500)
          .background(Color(nsColor: .windowBackgroundColor))

        }
      }
      .ignoresSafeArea()
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(.gray.opacity(0.5))
      }
      .onAppear{ isFocused = true }
    }
  }

  class HostedCompletionView: NSHostingView<CompletionView> {

    override func becomeFirstResponder() -> Bool {

      // This is very dodgy, but I just don't know another way to make the initial first responder a SwiftUI view
      // somewhere inside the guts of this hosting view.
      DispatchQueue.main.async { [self] in
        window!.selectKeyView(following: self)
      }
      return true
    }

    @MainActor
    override func keyDown(with event: NSEvent) {
      guard let window = window as? CompletionPanel else { super.keyDown(with: event); return }

      if event.keyCode == keyCodeDownArrow || event.keyCode == keyCodeUpArrow {

        // Pass arrow keys to the panel view
        super.keyDown(with: event)

      } else if event.keyCode == keyCodeReturn {

        // Commit to current completion
        if let selectedCompletion = (window.completions.items.first{ $0.id == window.selection.selection }) {

          window.progressHandler?(.completion(selectedCompletion.insertText, selectedCompletion.insertRange))

        } else {

          window.progressHandler?(.cancel)

        }

      } else if event.keyCode == keyCodeESC {

        // cancel completion on ESC
        window.progressHandler?(.cancel)

      } else if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {

        // cancel completion and pass event on on any editing commands
        window.progressHandler?(.input(event))
        window.close()

      } else {

        // just pass on on anything we don't know about
        window.progressHandler?(.input(event))

      }
    }
  }

  class ObservableSelection: ObservableObject {
    @Published var selection: Int? = nil
  }

  /// The current set of completions.
  ///
  private(set) var completions: Completions = .none
  
  /// The `id` of the currently selected item in `completions`.
  ///
  private(set) var selection: ObservableSelection = ObservableSelection()

  /// Whenever there is progress in the completion interaction, this is fed back to the code view by reporting
  /// progress via this handler.
  ///
  /// NB: Whenver a finalising completion progress is being reported, this property is reset to `nil`. This allows
  ///     sending a `.cancel` from `close()` without risk of a superflous progress message.
  ///
  var progressHandler: ((CompletionProgress) -> Void)?

  /// The content view at its precise type.
  ///
  private let hostingView: HostedCompletionView

  /// The observer for the 'didResignKeyNotification' notification.
  ///
  private var didResignObserver: NSObjectProtocol?

  init() {
    hostingView = HostedCompletionView(rootView: CompletionView(completions: completions,
                                                                selection: ObservableSelection()))
    hostingView.sizingOptions = [.maxSize, .minSize]

    super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
               styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: true)
    collectionBehavior.insert(.fullScreenAuxiliary)
    isFloatingPanel             = true
    titleVisibility             = .hidden
    titlebarAppearsTransparent  = true
    isMovableByWindowBackground = false
    hidesOnDeactivate           = true
    animationBehavior           = .utilityWindow
    backgroundColor             = .clear

    standardWindowButton(.closeButton)?.isHidden       = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden        = true

    contentView = hostingView

    self.didResignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                                    object: self,
                                                                    queue: nil) { [weak self] _notification in

      self?.close()
    }
  }

  deinit {
    if let didResignObserver { NotificationCenter.default.removeObserver(didResignObserver) }
  }

  override var canBecomeKey: Bool { true }

  override func close() {
    // We cancel the completion process if the window gets closed (and the `progressHandler` is still active (i.e., it
    // is non-`nil`).
    if isKeyWindow { progressHandler?(.cancel) }
    super.close()
  }

  /// Set a list of completions and ensure that the completion panel is shown if the completion list is non-empty.
  ///
  /// - Parameters:
  ///   - completions: The new list of completions.
  ///   - screenRect: The rectangle enclosing the range of characters that form the prefix of the word that is being
  ///       completed. If no `rect` is provided, it is assumed that the last provided one is still valid. The
  ///       rectangle is in screen coordinates.
  ///   - explicitTrigger: The completion computation was explicitly triggered.
  ///   - handler: Closure used to report progress in the completion interaction back to the code view.
  ///
  /// The completion panel gets aligned such that `rect` leading aligns with the completion labels in the completion
  /// panel.
  ///
  func set(completions: Completions,
           anchoredAt screenRect: CGRect? = nil,
           explicitTrigger: Bool,
           handler: @escaping (CompletionProgress) -> Void)
  {
    var completions = completions

    completions.items.sort()

    self.completions     = completions
    self.progressHandler = handler

    if let screenRect {
      // FIXME: the panel needs to be above or below the rectangle depending on its position and size
      // FIXME: the panel needs to be aligned at the completion labels and not at its leading edge
      setFrameTopLeftPoint(CGPoint(x: screenRect.minX, y: screenRect.minY))
    }

    // The initial selection is the first item marked as selected, if any, or otherwise, the first item in the list.
    selection.selection = if let selected = (completions.items.first{ $0.selected }) { selected.id }
                          else { completions.items.first?.id }

    // Update the view and show the window if and only if there are completion items to show.
    if completions.items.isEmpty && !explicitTrigger { close() }
    else {

      hostingView.rootView = CompletionView(completions: self.completions, selection: selection)
      if !isVisible {

        makeKeyAndOrderFront(nil)
        makeFirstResponder(contentView)

      }

      // Refine all refinable items.
      Task { @MainActor in
        for item in self.completions.items.enumerated() {
          if let refinedItem = try? await item.element.refine() {
            self.completions.items[item.offset] = refinedItem
            // This doesn't trigger an update (maybe, because only `AnyView` subviews change?)...
//            hostingView.rootView = CompletionView(completions: completions, selection: selection)
          }
        }
        // ...hence, we update the whole thing.
        contentView = HostedCompletionView(rootView: CompletionView(completions: self.completions,
                                                                    selection: selection))
      }
    }
  }
}


#Preview {
  @Previewable @StateObject var selection = CompletionPanel.ObservableSelection()
  let completions = Completions(isIncomplete: false,
                                items: [
                                  Completions.Completion(id: 1,
                                                         rowView: { _ in Text("foo") },
                                                         documentationView: Text("Best function!"),
                                                         selected: false,
                                                         sortText: "foo",
                                                         filterText: "foo",
                                                         insertText: "foo",
                                                         insertRange: NSRange(location: 0, length: 1),
                                                         commitCharacters: [],
                                                         refine: { nil }),
                                  Completions.Completion(id: 2,
                                                         rowView: { _ in Text("fop") },
                                                         documentationView: Text("Second best function!"),
                                                         selected: false,
                                                         sortText: "fop",
                                                         filterText: "fop",
                                                         insertText: "fop",
                                                         insertRange: NSRange(location: 0, length: 1),
                                                         commitCharacters: [],
                                                         refine: { nil }),
                                  Completions.Completion(id: 3,
                                                         rowView: { _ in Text("fabc") },
                                                         documentationView: Text("My best function!"),
                                                         selected: false,
                                                         sortText: "fabc",
                                                         filterText: "fabc",
                                                         insertText: "fabc",
                                                         insertRange: NSRange(location: 0, length: 1),
                                                         commitCharacters: [],
                                                         refine: { nil }),
                                ])
  CompletionPanel.CompletionView(completions: completions, selection: selection)
}

extension CodeView {

  /// Sets a new list of completions and positions the completions panel such that it aligned with the given character
  /// range.
  ///
  /// - Parameters:
  ///   - completions: The new list of completions to be displayed.
  ///   - range: The characters range at whose leading edge the completion panel is to be aligned.
  ///   - explicitTrigger: The completion computation was explicitly triggered.
  ///
  @MainActor
  func show(completions: Completions, for range: NSRange, explicitTrigger: Bool) {

    completionPanel.set(completions: completions, 
                        anchoredAt: firstRect(forCharacterRange: range, actualRange: nil),
                        explicitTrigger: explicitTrigger) {
      [weak self] completionProgress in

      switch completionProgress {

      case .cancel:
        self?.completionPanel.progressHandler = nil
        self?.completionPanel.close()

      case .completion(let insertText, let insertRange):
        // FIXME: Using `range` when there is no `insertRange` is dangerous. It requires `rangeForUserCompletion` to match what the LSP service regards as the word prefix. Better would be to scan the code storage for the prefix of `insertText`.
        self?.insertText(insertText, replacementRange: insertRange ?? range)
        self?.completionPanel.progressHandler = nil
        self?.completionPanel.close()

      case .input(let event):
        self?.interpretKeyEvents([event])
      }
    }
  }

  /// Actually do query the language service for code completions and display them.
  ///
  /// - Parameters:
  ///   - location: The character location for which code completions are requested.
  ///   - explicitTrigger: The completion computation was explicitly triggered.
  ///
  func computeAndShowCompletions(at location: Int, explicitTrigger: Bool) async throws {
    guard let languageService = optLanguageService else { return }

    do {

      let reason: CompletionTriggerReason = if completionPanel.isKeyWindow { .incomplete } else { .standard },
          completions                     = try await languageService.completions(at: location, reason: reason)
      try Task.checkCancellation()   // may have been cancelled in the meantime due to further user action
      show(completions: completions, for: rangeForUserCompletion, explicitTrigger: explicitTrigger)

    } catch let error { logger.trace("Completion action failed: \(error.localizedDescription)") }
  }
  
  /// Explicitly user initiated completion action by a command or trigger character.
  ///
  func completionAction() {

    // Stop any already running completion task
    completionTask?.cancel()

    // If we already show the completion panel close it — we want the shortcut to toggle visbility. Otherwise,
    // initiate a completion task.
    if completionPanel.isKeyWindow {

      completionPanel.close()

    } else {

      let location = selectedRange().location
      if let codeStorageDelegate = optCodeStorage?.delegate as? CodeStorageDelegate,
         !codeStorageDelegate.lineMap.isWithinComment(range: NSRange(location: location, length: 0))
      {
        completionTask = Task {
          try await computeAndShowCompletions(at: location, explicitTrigger: true)
        }
      }

    }
  }
  
  /// FIXME: This is language dependent and should take the language configuration into account. (In Haskell, it
  /// FIXME: should, .e.g., include "'" as well.)
  private static let identifierCharacterSet = CharacterSet.alphanumerics.union(.init(charactersIn: "_"))

  /// This function needs to be invoked whenever the completion range changes; i.e., once a text change has been made.
  ///
  /// - Parameter range: The current completion range (range of partial word in front of the insertion point) as
  ///       reported by the text view.
  ///
  func considerCompletionFor(range: NSRange) {

    /// We don't want to automatically trigger completion for ranges that do not produce sensible results, such as
    /// ranges of purely numeric characters. Moreover, we do not automatically trigger completions for ranges that end
    /// in the middle of an identifier.
    ///
    func rangeContentsWarrantsAutoCompletion() -> Bool {
      guard let codeStorage = optCodeStorage,
            let substring   = codeStorage.string[range]
      else { return false }

      // FIXME: For languages with user-definable symbol identifiers, it would make sense to trigger auto-completion for
      // FIXME: ranges that consist of symbols only, but, e.g., the Haskell Language Server doesn't seem to return
      // FIXME: sensible results. This ought to be improved.

      // For now, we look for at least one letter.
      let atLeastOneLetter = substring.unicodeScalars.first{ CharacterSet.letters.contains($0) } != nil

      let notInMiddleOfIndentifier = if let next = codeStorage.string[NSRange(location: range.max, length: 1)],
                                        let nextCharacter = next.unicodeScalars.first
                                     {
                                       !CodeView.identifierCharacterSet.contains(nextCharacter)
                                     } else { true }

      return atLeastOneLetter && notInMiddleOfIndentifier
    }

    guard let codeStorageDelegate = optCodeStorage?.delegate as? CodeStorageDelegate else { return }

    // Stop any already running completion task
    completionTask?.cancel()

    let withinComment = codeStorageDelegate.lineMap.isWithinComment(range: NSRange(location: range.max, length: 0))
    if range.length > 0 && !withinComment && codeStorageDelegate.processingOneCharacterAddition
        && rangeContentsWarrantsAutoCompletion()
    {

      completionTask = Task {

        // Delay completion a bit at the start of a word (the user may still be typing) unless the completion window
        // is already open.
        // NB: throws if task gets cancelled in the meantime.
        if range.length < 3 && !completionPanel.isKeyWindow { try await Task.sleep(until: .now + .seconds(0.2)) }

        // Trigger completion
        try await computeAndShowCompletions(at: range.max, explicitTrigger: false)
      }

    } else if range.length == 0 && completionPanel.isKeyWindow {

      // If the incomplete word get deleted, while the panel is open, close it
      completionPanel.close()

    }
  }

}

#endif
