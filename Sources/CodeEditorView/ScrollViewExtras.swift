//
//  ScrollView.swift
//  
//
//  Created by Manuel M T Chakravarty on 27/11/2021.
//

import SwiftUI


#if os(iOS) || os(visionOS)

// MARK: -
// MARK: UIKit version

extension UIScrollView {

  var verticalScrollPosition: CGFloat {
    get { contentOffset.y }
    set {
      let newOffset = max(0, min(newValue, bounds.height - contentSize.height))
      if abs(newOffset - contentOffset.y) > 0.0001 {
        setContentOffset(CGPoint(x: contentOffset.x, y: newOffset), animated: false)
      }
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

      (documentView as? CodeView)?.textLayoutManager?.textViewportLayoutController.layoutViewport()

      let newOffset = max(0, min(newValue, (documentView?.bounds.height ?? 0) - contentSize.height))
      if abs(newOffset - documentVisibleRect.origin.y) > 0.0001 {
        contentView.scroll(to: CGPoint(x: documentVisibleRect.origin.x, y: newOffset))
      }

      // This is necessary as the floating subviews are otherwise *sometimes* not correctly re-positioned.
      reflectScrolledClipView(contentView)

    }
  }
}

#endif
