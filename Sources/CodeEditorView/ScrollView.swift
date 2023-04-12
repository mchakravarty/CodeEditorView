//
//  ScrollView.swift
//  
//
//  Created by Manuel M T Chakravarty on 27/11/2021.
//

import SwiftUI


#if os(iOS)

// MARK: -
// MARK: UIKit version

extension UIScrollView {

  var verticalScrollPosition: CGFloat {
    get { contentOffset.y }
    set {
      let newOffset = max(0, min(newValue, contentSize.height - bounds.height))
      setContentOffset(CGPoint(x: contentOffset.x, y: newOffset), animated: false)
    }
  }
}


#elseif os(macOS)

// MARK: -
// MARK: AppKit version

extension NSScrollView {

  var verticalScrollPosition: CGFloat {
    get { documentVisibleRect.origin.y }
    set {
      let newOffset = max(0, min(newValue, contentSize.height - bounds.height))
      contentView.scroll(to: CGPoint(x: documentVisibleRect.origin.x, y: newOffset))
    }
  }
}

#endif
