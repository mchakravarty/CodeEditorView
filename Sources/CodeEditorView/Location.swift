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

/// Location in a text in terms of a line-column position, where the line and column count starts at 1.
///
public struct TextLocation {

  /// The line of the location, starting with 1.
  ///
  public let line: Int

  /// The column in `line` of the specified location, starting with column 1.
  ///
  public let column: Int

  public init(line: Int, column: Int) {
    self.line   = line
    self.column = column
  }
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

  public var line:   Int { location.line }
  public var column: Int { location.column }

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
  ///   - line: The line within the given `file`.
  ///   - column: The column on the `line` within the given `file`.
  ///
  public  init(file: FilePath, line: Int, column: Int) {
    self.init(file: file, location: TextLocation(line: line, column: column))
  }
}

/// Generic location attribute.
///
public struct Located<Entity> {
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

extension Located: Equatable where Entity: Equatable {
  static public func == (lhs: Located<Entity>, rhs: Located<Entity>) -> Bool {
    lhs.entity == rhs.entity
  }
}

extension Located: Hashable where Entity: Hashable {
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

  /// The last line containing at least one character of the span. This may be the same line as `start.location.line`.
  ///
  public let endLine:   Int

  /// The column at which the last character of the span is located.
  ///
  public let endColumn: Int

  /// Produce a span from a start location together with an end line and end column.
  ///
  /// - Parameters:
  ///   - start: The location where the span starts.
  ///   - endLine: The last line containing at least one character of the span.
  ///   - endColumn: The column at which the last character of the span is located.
  ///
  public init(start: FileLocation, endLine: Int, endColumn: Int) {
    self.start = start
    self.endLine = endLine
    self.endColumn = endColumn
  }
}
