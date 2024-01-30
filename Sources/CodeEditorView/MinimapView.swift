//
//  MinimapView.swift
//  
//
//  Created by Manuel M T Chakravarty on 05/05/2021.
//
//  TextKit 2 subclasses to implement minimap functionality.
//
//  The idea here is that, in place of drawing the actual glyphs, we draw small rectangles in the glyph's foreground
//  colour. Instead of actual glyphs, we draw fixed-sized rectangles. The size of the minimap rectangles corresponds
//  to that of the main code view font, but at a fraction of the fontsize determined by `minimapRatio`.
//
//  The implementation generates custom `NSTextParagraph`s with a font scaled down by a factor of `minimapRatio`. We
//  achieve this with a custom `NSTextContentStorageDelegate`. This implies that we cannot use the some
//  `NSTextContentStorage` for a code view and for its associated minimap. This is somewhat of a problem, because
//  TextKit 2 only supports a single `NSTextContentStorage` for a given `NSTextStorage`. To work around this
//  limitation, we define two custom subclasses of `NSTextStorage`, namely `CodeContentStorage` and 
//  `TextStorageObserver`, where the former serves as the principal code storage and the latter functions as a read-only
//  forwarder for the minimap.
//
//  To replace the standard glyph drawing by drawing of the rectangle, we subclass `NSTextLineFragment` and use a
//  subclass of `NSTextLayoutFragment` to generate the custom `NSTextLineFragment`.

import SwiftUI


/// The factor determining how much smaller the minimap is than the actual code view.
///
let minimapRatio = CGFloat(8)


#if os(iOS)

// MARK: -
// MARK: Minimap view for iOS

/// Customised text view for the minimap.
///
class MinimapView: UITextView {
  weak var codeView: CodeView?

  // Highlight the current line.
  //
  override func draw(_ rect: CGRect) {
    super.draw(rect)

    let rectWithinBounds = rect.intersection(bounds)

    guard let textLayoutManager  = textLayoutManager,
          let textContentStorage = textLayoutManager.textContentManager as? NSTextContentStorage
    else { return }

    let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange

    // If the selection is an insertion point, highlight the corresponding line
    if let location     = insertionPoint,
       let textLocation = textContentStorage.textLocation(for: location)
    {
      if viewportRange == nil
          || viewportRange!.contains(textLocation)
          || viewportRange!.endLocation.compare(textLocation) == .orderedSame
      {
        drawBackgroundHighlight(within: rectWithinBounds,
                                forLineContaining: textLocation,
                                withColour: codeView?.theme.currentLineColour ?? .systemBackground)
      }
    }
  }
}


#elseif os(macOS)

// MARK: -
// MARK: Minimap view for macOS

/// Customised text view for the minimap.
///
class MinimapView: NSTextView {
  weak var codeView: CodeView?

  // Highlight the current line.
  //
  override func drawBackground(in rect: NSRect) {
    let rectWithinBounds = rect.intersection(bounds)
    super.drawBackground(in: rectWithinBounds)

    guard let textLayoutManager  = textLayoutManager,
          let textContentStorage = textContentStorage
    else { return }

    let viewportRange = textLayoutManager.textViewportLayoutController.viewportRange

    // If the selection is an insertion point, highlight the corresponding line
    if let location     = insertionPoint,
       let textLocation = textContentStorage.textLocation(for: location)
    {
      if viewportRange == nil
          || viewportRange!.contains(textLocation)
          || viewportRange!.endLocation.compare(textLocation) == .orderedSame
      {
        drawBackgroundHighlight(within: rectWithinBounds,
                                forLineContaining: textLocation,
                                withColour: codeView?.theme.currentLineColour ?? .textBackgroundColor)
      }
    }
  }
}

#endif


// MARK: -
// MARK: Minimap attribute injection

class MinimapContentStorageDelegate: NSObject, NSTextContentStorageDelegate {

  func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange)
  -> NSTextParagraph?
  {
    let text = NSMutableAttributedString(attributedString: 
                                         textContentStorage.attributedString!.attributedSubstring(from: range)),
        font = if range.length > 0,
                  let font = text.attribute(.font, at: 0, effectiveRange: nil) as? OSFont { font }
               else { OSFont.monospacedSystemFont(ofSize: 0, weight: .regular) }
    text.addAttribute(.font,
                      value: OSFont(name: font.fontName, size: font.pointSize / minimapRatio)!,
                      range: NSRange(location: 0, length: range.length))

    return NSTextParagraph(attributedString: text)
  }
}


// MARK: -
// MARK: Minimap layout functionality 

class MinimapLineFragment: NSTextLineFragment {

  /// Text line fragment that we base our derived fragment on.
  ///
  /// `NSTextLineFragment` is a class cluster; hence, we need to embded a fragment generated by TextKit for us to get
  /// at its properties.
  ///
  private let textLineFragment: NSTextLineFragment
  
  /// All rendering attribute runs applying to this line.
  ///
  private let attributes: [MinimapLayoutFragment.AttributeRun]

  /// The advacement per glyph (for a monospaced font).
  ///
  private let advancement: CGFloat

  init(_ textLineFragment: NSTextLineFragment, attributes: [MinimapLayoutFragment.AttributeRun]) {
    self.textLineFragment = textLineFragment
    self.attributes       = attributes

    let attributedString = textLineFragment.attributedString,
        range            = textLineFragment.characterRange

    // Determine the advancement per glyph (assuming a monospaced font)
    let font = if range.length > 0,
                  let font = attributedString.attribute(.font, at: range.location, effectiveRange: nil) as? OSFont { font }
               else { OSFont.monospacedSystemFont(ofSize: OSFont.systemFontSize, weight: .regular) }
    advancement = font.maximumHorizontalAdvancement

    super.init(attributedString: attributedString, range: range)
  }

  required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override var glyphOrigin: CGPoint { textLineFragment.glyphOrigin }

  override var typographicBounds: CGRect { textLineFragment.typographicBounds }

  override func characterIndex(for point: CGPoint) -> Int { textLineFragment.characterIndex(for: point) }

  override func fractionOfDistanceThroughGlyph(for point: CGPoint) -> CGFloat {
    textLineFragment.fractionOfDistanceThroughGlyph(for: point)
  }

  override func locationForCharacter(at index: Int) -> CGPoint {
    textLineFragment.locationForCharacter(at: index)
  }

  // Draw boxes using a character's foreground colour instead of actual glyphs.
  override func draw(at point: CGPoint, in context: CGContext) {

    // Leave some space between glyph boxes on adjacent lines
    let gap = typographicBounds.height * 0.3

    for attribute in attributes {

      let attributeRect = CGRect(x: floor(point.x + advancement * CGFloat(attribute.range.location)),
                                 y: floor(point.y + gap / 2),
                                 width: floor(advancement * CGFloat(attribute.range.length)),
                                 height: typographicBounds.height - gap)
      if let colour = attribute.attributes[.foregroundColor] as? OSColor {
        colour.withAlphaComponent(0.50).setFill()
      }
      OSBezierPath(rect: attributeRect).fill()
    }
  }
}

/// Minimap layout fragments replaces all line fragments by a our own variant of minimap line fragments, which draw
/// coloured boxes instead of actual glyphs.
///
class MinimapLayoutFragment: NSTextLayoutFragment {

  private var _textLineFragments: [NSTextLineFragment] = []

  private var observation: NSKeyValueObservation?

  @objc override dynamic var textLineFragments: [NSTextLineFragment] {
    return _textLineFragments
  }

  override init(textElement: NSTextElement, range rangeInElement: NSTextRange?) {
    super.init(textElement: textElement, range: rangeInElement)
    observation = super.observe(\.textLineFragments, options: [.new]){ [weak self] _, _ in

      // NB: We cannot use `change.newValue` as this seems to pull the value from the subclass property (which we
      //     want to update here). Instead, we need to directly access `super`. This is, however as per Swift 5.9
      //     not possible in a closure weakly capturing `self` (which we need to do here to avoid a retain cycle).
      //     Hence, we defer to an auxilliary method.
      self?.updateTextLineFragments()
    }
  }
  
  typealias AttributeRun = (attributes: [NSAttributedString.Key : Any], range: NSRange)

  // We don't draw white space and control characters
  private let      invisibleCharacterers       = CharacterSet.whitespacesAndNewlines.union(CharacterSet.controlCharacters)
  private lazy var invertedInvisibleCharacters = invisibleCharacterers.inverted

  /// Update the text line fragments from the corresponding property of `super`.
  ///
  private func updateTextLineFragments() {
    if let textLayoutManager = self.textLayoutManager {

      var location       = rangeInElement.location
      _textLineFragments = []
      for fragment in super.textLineFragments {
        guard let string = (fragment.attributedString.string[fragment.characterRange].flatMap{ String($0) }) 
        else { break }

        let attributeRuns
          = if let endLocation = textLayoutManager.location(location, offsetBy: fragment.characterRange.length),
               let textRange   = NSTextRange(location: location, end: endLocation)
          {

            textLayoutManager.renderingAttributes(in: textRange).map { attributeRun in
              (attributes: attributeRun.attributes,
               range: NSRange(location: textLayoutManager.offset(from: location, to: attributeRun.textRange.location),
                              length: textLayoutManager.offset(from: attributeRun.textRange.location, to: attributeRun.textRange.endLocation)))
            }
          } else { [AttributeRun]() }

        var attributeRunsWithoutWhitespace: [AttributeRun] = []
        for (attributes, range) in attributeRuns {

          if attributes[.hideInvisibles] == nil {
            attributeRunsWithoutWhitespace.append((attributes: attributes, range: range))
          } else {

            var remainingRange = range
            while remainingRange.length > 0,
                  let match = string.rangeOfCharacter(from: invisibleCharacterers, range: remainingRange.range(in: string))
            {

              let lower = match.lowerBound.utf16Offset(in: string),
                  upper = min(match.upperBound.utf16Offset(in: string), remainingRange.max)

              // If we have got a prefix with visible characters, emit an attribute run covering those.
              if lower > remainingRange.location {
                attributeRunsWithoutWhitespace.append((attributes: attributes,
                                                       range: NSRange(location: remainingRange.location,
                                                                      length: lower - remainingRange.location)))
              }

              // Advance the remaining range to after the character found in `match`.
              remainingRange = NSRange(location: upper,
                                       length: remainingRange.length - (upper - remainingRange.location))

              if let nextVisibleCharacter = string.rangeOfCharacter(from: invertedInvisibleCharacters,
                                                                    range: remainingRange.range(in: string))
              {

                // If there is another visible character, the new remaining range starts with that character.
                let lower = nextVisibleCharacter.lowerBound.utf16Offset(in: string)
                remainingRange = NSRange(location: lower,
                                         length: remainingRange.length - (lower - remainingRange.location))

              } else {  // If there are no more visible characters, we are done.
                remainingRange.length = 0
              }
            }
          }
        }
        _textLineFragments.append(MinimapLineFragment(fragment, attributes: attributeRunsWithoutWhitespace))
        location = textLayoutManager.location(location, offsetBy: fragment.characterRange.length) ?? location
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class MinimapTextLayoutManagerDelegate: NSObject, NSTextLayoutManagerDelegate {

  // We create instances of our own flavour of layout fragments
  func textLayoutManager(_ textLayoutManager: NSTextLayoutManager,
                         textLayoutFragmentFor location: NSTextLocation,
                         in textElement: NSTextElement)
  -> NSTextLayoutFragment
  {
    guard let paragraph = textElement as? NSTextParagraph
    else { return NSTextLayoutFragment(textElement: textElement, range: nil)  }

    return MinimapLayoutFragment(textElement: paragraph, range: nil)
  }
}
