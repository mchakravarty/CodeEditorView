//
//  SIzedCodeView.swift
//  CodeEditorView
//
//  Created by Murilo Araujo on 25/11/24.
//
import SwiftUI
import LanguageSupport
import Combine

public struct SizedCodeEditor: View {
    let language:            LanguageConfiguration
    let layout:              CodeEditor.LayoutConfiguration
    let breakUndoCoalescing: PassthroughSubject<(), Never>?
    let setActions:          ((CodeEditor.Actions) -> Void)?
    let setInfo:             ((CodeEditor.Info) -> Void)?
    @State var height: CGFloat = 100
    @Binding private var text:     String
    @Binding private var position: CodeEditor.Position
    @Binding private var messages: Set<TextLocated<Message>>
    @Binding private var dynamicViewHeight: CGFloat
    
    public init(text:                Binding<String>,
                position:            Binding<CodeEditor.Position>,
                messages:            Binding<Set<TextLocated<Message>>>,
                language:            LanguageConfiguration = .none,
                layout:              CodeEditor.LayoutConfiguration = .standard,
                breakUndoCoalescing: PassthroughSubject<(), Never>? = nil,
                setActions:          ((CodeEditor.Actions) -> Void)? = nil,
                setInfo:             ((CodeEditor.Info) -> Void)? = nil)
    {
        self._dynamicViewHeight = .constant(0)
        self._text               = text
        self._position           = position
        self._messages           = messages
        self.language            = language
        self.layout              = layout
        self.breakUndoCoalescing = breakUndoCoalescing
        self.setActions          = setActions
        self.setInfo             = setInfo
    }
    
    public var body: some View {
        CodeEditor(text: $text, position: $position, messages: $messages, language: language, layout: layout, breakUndoCoalescing: breakUndoCoalescing, setActions: setActions, setInfo: setInfo, dynamicHeight: $height)
            .frame(minHeight: height, maxHeight: height)
    }
}
