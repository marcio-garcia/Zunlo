//
//  PrimarySecureField.swift
//  GlowUI
//
//  Created by Marcio Garcia on 9/24/25.
//

import SwiftUI

public struct PrimarySecureField: View {
    // MARK: - Properties
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    // MARK: - Configuration Properties
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
        SecureField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .themedBody()
            .padding(padding)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: cornerStyle
                )
                .fill(backgroundColor)
            )
            .overlay(alignment: .center, content: {
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: cornerStyle
                )
                .stroke(
                    currentFocusState ? focusedBorderColor : unfocusedBorderColor,
                    lineWidth: currentFocusState ? focusedBorderWidth : unfocusedBorderWidth
                )

            })
            .animation(.easeInOut(duration: animationDuration), value: currentFocusState)
            .focused(focusedBinding ?? $isFocused)
    }
    
    // MARK: - Computed Properties
    private var currentFocusState: Bool {
        focusedBinding?.wrappedValue ?? isFocused
    }
}

// MARK: - Configuration Methods
extension PrimarySecureField {
    /// Sets the minimum height
    func minHeight(_ height: CGFloat) -> PrimarySecureField {
        var copy = self
        copy.minHeight = height
        return copy
    }
    
    /// Sets the internal padding
    func padding(_ padding: CGFloat) -> PrimarySecureField {
        var copy = self
        copy.padding = padding
        return copy
    }
    
    /// Sets the corner radius
    func cornerRadius(_ radius: CGFloat) -> PrimarySecureField {
        var copy = self
        copy.cornerRadius = radius
        return copy
    }
    
    /// Sets the corner style
    func cornerStyle(_ style: RoundedCornerStyle) -> PrimarySecureField {
        var copy = self
        copy.cornerStyle = style
        return copy
    }
    
    /// Sets the background color
    func backgroundColor(_ color: Color) -> PrimarySecureField {
        var copy = self
        copy.backgroundColor = color
        return copy
    }
    
    /// Sets the border colors for focused and unfocused states
    func borderColors(focused: Color, unfocused: Color) -> PrimarySecureField {
        var copy = self
        copy.focusedBorderColor = focused
        copy.unfocusedBorderColor = unfocused
        return copy
    }
    
    /// Sets the border widths for focused and unfocused states
    func borderWidths(focused: CGFloat, unfocused: CGFloat) -> PrimarySecureField {
        var copy = self
        copy.focusedBorderWidth = focused
        copy.unfocusedBorderWidth = unfocused
        return copy
    }
    
    /// Sets the animation duration for focus state changes
    func animationDuration(_ duration: Double) -> PrimarySecureField {
        var copy = self
        copy.animationDuration = duration
        return copy
    }
}

// MARK: - Usage Examples
//struct PrimarySecureFieldExamples: View {
//    @State private var password = ""
//    @State private var confirmPassword = ""
//    @State private var pin = ""
//    @FocusState private var isPasswordFocused: Bool
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // Basic usage
//            PrimarySecureField("Password", text: $password, focused: $isPasswordFocused)
//            
//            // Confirm password with custom styling
//            PrimarySecureField("Confirm Password", text: $confirmPassword)
//                .borderColors(
//                    focused: .green,
//                    unfocused: .gray.opacity(0.3)
//                )
//            
//            // Compact PIN entry
//            PrimarySecureField("PIN", text: $pin)
//                .minHeight(36)
//                .cornerRadius(8)
//                .padding(8)
//                .backgroundColor(Color(.secondarySystemBackground))
//        }
//        .padding()
//    }
//}
//
// MARK: - Combined Usage Example
//struct PrimaryFieldsExample: View {
//    @State private var email = ""
//    @State private var password = ""
//    @FocusState private var focusedField: FocusedField?
//    
//    enum FocusedField {
//        case email, password
//    }
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            // Text field for email
//            PrimaryTextField("Email", text: $email)
//                .focused($focusedField, equals: .email)
//                .axis(.horizontal)
//                .lineLimit(1...1)
//            
//            // Secure field for password
//            PrimarySecureField("Password", text: $password)
//                .focused($focusedField, equals: .password)
//            
//            Button("Sign In") {
//                // Handle sign in
//            }
//            .buttonStyle(.borderedProminent)
//        }
//        .padding()
//        .navigationTitle("Sign In")
//    }
//}
//
//// MARK: - Preview
//#Preview {
//    NavigationView {
//        PrimaryFieldsExample()
//    }
//}
