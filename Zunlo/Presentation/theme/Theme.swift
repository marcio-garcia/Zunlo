//
//  Theme.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/16/25.
//

import SwiftUI

// MARK: - Theme Colors & Fonts

struct Theme {
    let accent: Color
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    let success: Color
    let border: Color

    // Add more semantic roles as needed

    static let light = Theme(
        accent: Color(themeHex: "#F6A192"), // Coral Peach
        background: Color(themeHex: "#FAF3F0"), // Porcelain Pink
        surface: Color(themeHex: "#FDF1E7"), // Light Sand
        text: Color(themeHex: "#44403C"), // Warm Graphite
        secondaryText: Color(themeHex: "#6B4C46"), // Slightly lighter warm gray
        success: Color(themeHex: "#C9E4CA"), // Mint Cream
        border: Color(themeHex: "#DAB7AB") // Dusty Blush
    )

    static let dark = Theme(
        accent: Color(themeHex: "#E98578"),
        background: Color(themeHex: "#2B2623"),
        surface: Color(themeHex: "#3B3532"),
        text: Color(themeHex: "#EAE2DF"),
        secondaryText: Color(themeHex: "#C9BBB5"),
        success: Color(themeHex: "#98C9A3"),
        border: Color(themeHex: "#5A4944")
    )
}

extension Color {
    static var theme: Theme {
        UITraitCollection.current.userInterfaceStyle == .dark ? Theme.dark : Theme.light
    }

    /// Convenience init for hex codes
    init(themeHex hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Fonts

enum AppFont {
    private static func loadFont(name: String, size: CGFloat, fallback: Font) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        } else {
            return fallback
        }
    }

    static func largeTitle(size: CGFloat = 34) -> Font {
        loadFont(name: "Quicksand-Bold", size: size,
                 fallback: .system(size: size, weight: .bold, design: .rounded))
    }

    static func title(size: CGFloat = 28) -> Font {
        loadFont(name: "Quicksand-Bold", size: size,
                 fallback: .system(size: size, weight: .semibold, design: .rounded))
    }

    static func subtitle(size: CGFloat = 22) -> Font {
        loadFont(name: "Quicksand-Medium", size: size,
                 fallback: .system(size: size, weight: .medium, design: .rounded))
    }

    static func heading(size: CGFloat = 20) -> Font {
        loadFont(name: "Quicksand-SemiBold", size: size,
                 fallback: .system(size: size, weight: .semibold, design: .rounded))
    }

    static func body(size: CGFloat = 17) -> Font {
        loadFont(name: "Quicksand-Regular", size: size,
                 fallback: .system(size: size, weight: .regular, design: .rounded))
    }

    static func callout(size: CGFloat = 16) -> Font {
        loadFont(name: "Quicksand-Regular", size: size,
                 fallback: .system(size: size, weight: .regular, design: .rounded))
    }

    static func button(size: CGFloat = 16) -> Font {
        loadFont(name: "Quicksand-SemiBold", size: size,
                 fallback: .system(size: size, weight: .semibold, design: .rounded))
    }

    static func caption(size: CGFloat = 13) -> Font {
        loadFont(name: "Quicksand-Medium", size: size,
                 fallback: .system(size: size, weight: .medium, design: .rounded))
    }

    static func footnote(size: CGFloat = 12) -> Font {
        loadFont(name: "Quicksand-Regular", size: size,
                 fallback: .system(size: size, weight: .regular, design: .rounded))
    }

    static func label(size: CGFloat = 11) -> Font {
        loadFont(name: "Quicksand-Regular", size: size,
                 fallback: .system(size: size, weight: .regular, design: .rounded))
    }
}


// MARK: - ViewModifiers for Theme

struct ThemedTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.body())
    }
}

struct ThemedHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.heading())
    }
}

struct ThemedCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.caption())
    }
}

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
    }
}

struct ThemedPrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.theme.accent)
            .foregroundColor(.white)
            .font(AppFont.button())
            .cornerRadius(8)
    }
}

struct ThemedSecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .font(AppFont.button())
            .cornerRadius(8)
    }
}

extension View {
    func themedText() -> some View {
        self.modifier(ThemedTextModifier())
    }
    
    func themedHeadline() -> some View {
        self.modifier(ThemedHeadlineModifier())
    }
    
    func themedCaption() -> some View {
        self.modifier(ThemedCaptionModifier())
    }

    func themedCard() -> some View {
        self.modifier(ThemedCardModifier())
    }

    func themedPrimaryButton() -> some View {
        self.modifier(ThemedPrimaryButtonModifier())
    }
    
    func themedSecondaryButton() -> some View {
        self.modifier(ThemedSecondaryButtonModifier())
    }
}

// MARK: - Example Usage

// Text("Welcome Back").themedText()
// RoundedRectangle(cornerRadius: 16).fill(Color.theme.surface)
//     .overlay(Text("Add Task").themedText())
// VStack { ... }.themedCard()
// Button("Save") { ... }.themedButton()
//
// Text("Important").font(AppFont.heading())
// Text("Details").font(AppFont.caption(size: 12))

//Text("Welcome").themedText()
//VStack {
//    Text("Today").font(AppFont.heading())
//    Text("No tasks yet").font(AppFont.caption())
//}
//.themedCard()
//
//Button("Save") { ... }.themedButton()
