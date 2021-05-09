//
//  Location.swift
//  
//
//  Created by Manuel M T Chakravarty on 09/05/2021.
//

import Foundation
import System


/// Location in a text file.
///
public struct Location {
  public let file:   FilePath
  public let line:   Int
  public let column: Int
}

/// Generic location attribute.
///
public struct Located<Entity> {
  public let location: Location
  public let entity:   Entity
}

/// Character span in a text file.
///
public struct Span {
  public let start:     Location
  public let endLine:   Int
  public let endColumn: Int
}
