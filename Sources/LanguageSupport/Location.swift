//
//  Location.swift
//  
//
//  Created by Manuel M T Chakravarty on 09/05/2021.
//
//  This file provides text positions and spans in a line-column format.

import Foundation
import System


// MARK: -
// MARK: Locations

/// Location in a text in terms of a line-column position, with support to use the line and column counts starting from
/// 0 or 1. The former is more convenient internally and the latter is better for user-facing information.
///
public struct TextLocation {

  /// The line of the location, starting from 0.
  ///
  public let zeroBasedLine: Int

  /// The column on `zeroBasedLine` of the specified location, starting with column 0.
  ///
  public let zeroBasedColumn: Int

  /// Creates a text location from zero-based line and column values.
  ///
  /// - Parameters:
  ///   - line: Zero-based line number
  ///   - column: Zero-based column number
  ///
  public init(zeroBasedLine line: Int, column: Int) {
    self.zeroBasedLine   = line
    self.zeroBasedColumn = column
  }

  /// Creates a text location from one-based line and column values.
  ///
  /// - Parameters:
  ///   - line: One-based line number
  ///   - column: One-based column number
  ///
  public init(oneBasedLine line: Int, column: Int) {
    self.zeroBasedLine   = line - 1
    self.zeroBasedColumn = column - 1
  }

  /// The line of the location, starting from 1.
  ///
  public var oneBasedLine: Int { zeroBasedLine + 1 }

  /// The column on `oneBasedLine` of the specified location, starting with column 1.
  ///
  public var oneBasedColumn: Int { zeroBasedColumn + 1 }
}

/// Protocol for a service converting between index positions of a string and text locations in line-column format.
///
public protocol LocationConverter {
  func textLocation(from location: Int) -> Result<TextLocation, Error>
  func location(from textLocation: TextLocation) -> Result<Int, Error>
}

/// Generic text location attribute.
///
public struct TextLocated<Entity> {
  public let location: TextLocation
  public let entity:   Entity

  /// Attribute the given entity with the given location.
  ///
  /// - Parameters:
  ///   - location: The location to aasociate the `entity` with.
  ///   - entity: The attributed entity.
  ///
  public init(location: TextLocation, entity: Entity) {
    self.location = location
    self.entity   = entity
  }
}

extension TextLocated: Equatable where Entity: Equatable {
  static public func == (lhs: TextLocated<Entity>, rhs: TextLocated<Entity>) -> Bool {
    lhs.entity == rhs.entity
  }
}

extension TextLocated: Hashable where Entity: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(entity) }
}

/// Location in a named text file in terms of a line-column position, where the line and column count starts at 1.
///
public struct FileLocation {


  /// The path of the text file containing the given text location.
  ///
  public let file: FilePath

  /// The location within the given `file`.
  ///
  public let location: TextLocation

  public var zeroBasedLine:   Int { location.zeroBasedLine }
  public var zeroBasedColumn: Int { location.zeroBasedColumn }

  public var oneBasedLine:   Int { location.oneBasedLine }
  public var oneBasedColumn: Int { location.oneBasedColumn }

  /// Construct a file location from a file path and a text location.
  ///
  /// - Parameters:
  ///   - file: The file containing the location.
  ///   - location: The location within the given file.
  ///
  public init(file: FilePath, location: TextLocation) {
    self.file     = file
    self.location = location
  }

  /// Construct a file location from a file path and a line and column within that file.
  ///
  /// - Parameters:
  ///   - file: The file containing the location.
  ///   - line: The line within the given `file`, starting from 0.
  ///   - column: The column (starting from zero) on the `line` within the given `file`.
  ///
  public  init(file: FilePath, zeroBasedLine line: Int, column: Int) {
    self.init(file: file, location: TextLocation(zeroBasedLine: line, column: column))
  }

  /// Construct a file location from a file path and a line and column within that file.
  ///
  /// - Parameters:
  ///   - file: The file containing the location.
  ///   - line: The line within the given `file`, starting from 1.
  ///   - column: The column (starting from one) on the `line` within the given `file`.
  ///
  public  init(file: FilePath, oneBasedLine line: Int, column: Int) {
    self.init(file: file, location: TextLocation(oneBasedLine: line, column: column))
  }
}

/// Generic file location attribute.
///
public struct FileLocated<Entity> {
  public let location: FileLocation
  public let entity:   Entity

  /// Attribute the given entity with the given location.
  ///
  /// - Parameters:
  ///   - location: The location to aasociate the `entity` with.
  ///   - entity: The attributed entity.
  ///
  public init(location: FileLocation, entity: Entity) {
    self.location = location
    self.entity   = entity
  }
}

extension FileLocated: Equatable where Entity: Equatable {
  static public func == (lhs: FileLocated<Entity>, rhs: FileLocated<Entity>) -> Bool {
    lhs.entity == rhs.entity
  }
}

extension FileLocated: Hashable where Entity: Hashable {
  public func hash(into hasher: inout Hasher) { hasher.combine(entity) }
}


// MARK: -
// MARK: Spans

/// Character span in a text file.
///
public struct Span {

  /// The location where the span starts.
  ///
  public let start: FileLocation

  /// The last line (starting from zero) containing at least one character of the span. This may be the same line as
  /// `start.location.line`.
  ///
  public let zeroBasedEndLine: Int

  /// The column (starting from zero) at which the last character of the span is located.
  ///
  public let zeroBasedEndColumn: Int

  /// Produce a span from a start location together with a zero-based end line and end column.
  ///
  /// - Parameters:
  ///   - start: The location where the span starts.
  ///   - endLine: The last line (starting from zero) containing at least one character of the span.
  ///   - endColumn: The column (starting from zero) at which the last character of the span is located.
  ///
  public init(start: FileLocation, zeroBasedEndLine endLine: Int, endColumn: Int) {
    self.start              = start
    self.zeroBasedEndLine   = endLine
    self.zeroBasedEndColumn = endColumn
  }

  /// Produce a span from a start location together with a one-based end line and end column.
  ///
  /// - Parameters:
  ///   - start: The location where the span starts.
  ///   - endLine: The last line (starting from one) containing at least one character of the span.
  ///   - endColumn: The column (starting from one) at which the last character of the span is located.
  ///
  public init(start: FileLocation, oneBasedEndLine endLine: Int, endColumn: Int) {
    self.start              = start
    self.zeroBasedEndLine   = endLine - 1
    self.zeroBasedEndColumn = endColumn - 1
  }

  /// The last line (starting from one) containing at least one character of the span. This may be the same line as
  /// `start.location.line`.
  ///
  public var oneBasedEndLine: Int { zeroBasedEndLine + 1 }

  /// The column (starting from one) at which the last character of the span is located.
  ///
  public var oneBasedCEndolumn: Int { zeroBasedEndColumn + 1 }
}
