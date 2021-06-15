#  Messages

The data model underlying messages is defined in [Message.swift](/Sources/CodeEditorView/Message.swift), whereas message rendering is defined in [MessageViews.swift](/Sources/CodeEditorView/MessageViews.swift). The message views are entirely implemented in SwiftUI and via `NSHostingView` and [UIHostingView.swift](/Sources/CodeEditorView/UIHostingView.swift), respectively, added as subviews to the [CodeView.swift](/Sources/CodeEditorView/CodeView.swift).

## Message views

Messages are always displayed in groups, namely as part of the group of messages that occur on a single line. The view of a message group has two flavours: (1) an inine view state and (2) a popup view state. Both of these views are combined inside the `StatefulMessageView`, which supports toggling between both flavours by clicking on the view.

### Inline view

The inline view is positioned at the right edge of the text container, precisely matching the height of the first line fragement rectangle of the line to which the message group pertains.

Due to the rather limited space, the inline view only provides a message group summary. This includes a tally of the number of messages in each category together with as much of the summary of the groups principal message as there is room to display. The principal message is always one of the messages of the most urgent category occuring in the message group. 

The width of the inline view is constrained by the width of the line on which it gets displayed. It will use the empty space to the right of the text to display as much of the message summary as it can. The inline view has got a minimal width (defined in `MessageView.minimumInlineWidth`), which it enforces by truncating the first line fragment rectangle of the line. If the line of code encroaches on the space needed for the inline view to display at its minimal width, the truncated line fragment rectangle will trigger a line break.

### Popup view

In contrast to the inline view, the popup view occupies as much space as it needs. It floats above the text, just underneath the last line fragment rectangle of the line that it belongs to. It is always offset a fixed amount from the right hand edge (`MessageView.popupRightSideOffset`) and also doesn't extend entirely to the text containers left hand side.

