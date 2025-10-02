//
//  PrimaryTextField.swift
//  GlowUI
//
//  Created by Marcio Garcia on 9/24/25.
//

import SwiftUI

public struct PrimaryTextField: View {
    // MARK: - Properties
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    // MARK: - Configuration Properties
    var axis: Axis = .vertical
    var lineLimit: ClosedRange<Int> = 1...6
    var minHeight: CGFloat = 42
    var padding: CGFloat = 10
    var cornerRadius: CGFloat = 12
    var cornerStyle: RoundedCornerStyle = .continuous
    var backgroundColor: Color = Color(.systemBackground)
    var focusedBorderColor: Color = Color.theme.border
    var unfocusedBorderColor: Color = Color.theme.lightBorder
    var focusedBorderWidth: CGFloat = 1.5
    var unfocusedBorderWidth: CGFloat = 1
    var animationDuration: Double = 0.15
    
    // Optional external focus binding
    var focusedBinding: FocusState<Bool>.Binding?
    
    // MARK: - Initializers
    public init(
        _ placeholder: String,
        text: Binding<String>,
        focused: FocusState<Bool>.Binding? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.focusedBinding = focused
    }
    
    // MARK: - Body
    public var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .textFieldStyle(.plain)
            .padding(padding)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: cornerStyle
                )
                .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: cornerStyle
                )
                .stroke(
                    currentFocusState ? focusedBorderColor : unfocusedBorderColor,
                    lineWidth: currentFocusState ? focusedBorderWidth : unfocusedBorderWidth
                )
            )
            .animation(.easeInOut(duration: animationDuration), value: currentFocusState)
            .focused(focusedBinding ?? $isFocused)
    }
    
    // MARK: - Computed Properties
    private var currentFocusState: Bool {
        focusedBinding?.wrappedValue ?? isFocused
    }
}

// MARK: - Configuration Methods
extension PrimaryTextField {
    /// Sets the text input axis
    public func axis(_ axis: Axis) -> PrimaryTextField {
        var copy = self
        copy.axis = axis
        return copy
    }
    
    /// Sets the line limit range
    public func lineLimit(_ range: ClosedRange<Int>) -> PrimaryTextField {
        var copy = self
        copy.lineLimit = range
        return copy
    }
    
    /// Sets the minimum height
    public func minHeight(_ height: CGFloat) -> PrimaryTextField {
        var copy = self
        copy.minHeight = height
        return copy
    }
    
    /// Sets the internal padding
    public func padding(_ padding: CGFloat) -> PrimaryTextField {
        var copy = self
        copy.padding = padding
        return copy
    }
    
    /// Sets the corner radius
    func cornerRadius(_ radius: CGFloat) -> PrimaryTextField {
        var copy = self
        copy.cornerRadius = radius
        return copy
    }
    
    /// Sets the corner style
    public func cornerStyle(_ style: RoundedCornerStyle) -> PrimaryTextField {
        var copy = self
        copy.cornerStyle = style
        return copy
    }
    
    /// Sets the background color
    public func backgroundColor(_ color: Color) -> PrimaryTextField {
        var copy = self
        copy.backgroundColor = color
        return copy
    }
    
    /// Sets the border colors for focused and unfocused states
    public func borderColors(focused: Color, unfocused: Color) -> PrimaryTextField {
        var copy = self
        copy.focusedBorderColor = focused
        copy.unfocusedBorderColor = unfocused
        return copy
    }
    
    /// Sets the border widths for focused and unfocused states
    public func borderWidths(focused: CGFloat, unfocused: CGFloat) -> PrimaryTextField {
        var copy = self
        copy.focusedBorderWidth = focused
        copy.unfocusedBorderWidth = unfocused
        return copy
    }
    
    /// Sets the animation duration for focus state changes
    public func animationDuration(_ duration: Double) -> PrimaryTextField {
        var copy = self
        copy.animationDuration = duration
        return copy
    }
}

//// MARK: - Usage Examples
//struct PrimaryTextFieldExamples: View {
//    @State private var message = ""
//    @State private var email = ""
//    @State private var notes = ""
//    @FocusState private var isMessageFocused: Bool
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Basic usage (matches your original)
//            PrimaryTextField("Message", text: $message, focused: $isMessageFocused)
//            
//            // Customized single-line input
//            PrimaryTextField("Email", text: $email)
//                .axis(.horizontal)
//                .lineLimit(1...1)
//                .cornerRadius(8)
//                .backgroundColor(Color(.secondarySystemBackground))
//            
//            // Larger text area with custom styling
//            PrimaryTextField("Notes", text: $notes)
//                .lineLimit(3...10)
//                .minHeight(80)
//                .padding(15)
//                .borderColors(
//                    focused: .blue,
//                    unfocused: .gray.opacity(0.3)
//                )
//                .animationDuration(0.2)
//        }
//        .padding()
//    }
//}
//
//// MARK: - Preview
//#Preview {
//    PrimaryTextFieldExamples()
//}
