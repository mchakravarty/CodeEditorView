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
      let newOffset = max(0, min(newValue, bounds.height - contentSize.height))
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
      let newOffset = max(0, min(newValue, (documentView?.bounds.height ?? 0) - contentSize.height))
      contentView.scroll(to: CGPoint(x: documentVisibleRect.origin.x, y: newOffset))

      // This is necessary as the floating subviews are otherwise *sometimes* not correctly re-positioned.
      reflectScrolledClipView(contentView)
    }
  }
}

#endif
