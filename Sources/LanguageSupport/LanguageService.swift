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
//  An instance of a language service is sepcific to a single file. Hence, locations etc are always relative to the file
//  associated with the used language service.

import SwiftUI
import Combine


/// Function that instantiates a language service from a location converter.
///
public typealias LanguageServiceBuilder = (LocationConverter) -> LanguageService

/// Determines the capabilities and endpoints for language-dependent external services, such as an LSP server.
///
public protocol LanguageService {

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
}
