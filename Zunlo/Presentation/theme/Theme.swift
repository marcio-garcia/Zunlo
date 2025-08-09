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
    let tertiaryText: Color
    let success: Color
    let border: Color
    let lightBorder: Color
    let disabled: Color
    let eventCellBackground: Color
    let highlightWarm1: Color
    let highlightWarm2: Color
    let highlightNeutral: Color
    let highlightCool1: Color
    
    // Add more semantic roles as needed

    static let light = Theme(
        accent: Color(hex: "#F6A192")!, // Coral Peach
        background: Color(hex: "#FAF4F2")!, // Porcelain Pink
        surface: Color(hex: "#FDF1E7")!, // Light Sand
        text: Color(hex: "#44403C")!, // Warm Graphite
        secondaryText: Color(hex: "#6B4C46")!, // Slightly lighter warm gray
        tertiaryText: Color(hex: "#B7A59F")!, // softer warm beige
        success: Color(hex: "#C9E4CA")!, // Mint Cream
        border: Color(hex: "#DAB7AB")!, // Dusty Blush
        lightBorder: Color(hex: "#ECD6CD")!,
        disabled: Color(hex: "#E0E0E0")!,
        eventCellBackground: Color(hex: "#F8E8DF")!, // Blended tone
        highlightWarm1: Color(hex: "#F6DAD1")!,
        highlightWarm2: Color(hex: "#F9EDE3")!,
        highlightNeutral: Color(hex: "#E8DED9")!,
        highlightCool1: Color(hex: "#D5EBDD")!
    )

    static let dark = Theme(
        accent: Color(hex: "#E98578")!,
        background: Color(hex: "#2B2623")!,
        surface: Color(hex: "#3B3532")!,
        text: Color(hex: "#EAE2DF")!,
        secondaryText: Color(hex: "#C9BBB5")!,
        tertiaryText: Color(hex: "#9C8F89")!, // muted warm beige
        success: Color(hex: "#98C9A3")!,
        border: Color(hex: "#5A4944")!,
        lightBorder: Color(hex: "#6E5A54")!,
        disabled: Color(hex: "#E0E0E0")!,
        eventCellBackground: Color(hex: "#473F3B")!,
        highlightWarm1: Color(hex: "#3F3532")!,
        highlightWarm2: Color(hex: "#514642")!,
        highlightNeutral: Color(hex: "#4C403C")!,
        highlightCool1: Color(hex: "#415C4C")!
    )
    
    static var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    static func highlightColor(for text: String) -> String {
        let options: [Color] = [
            Color.theme.highlightWarm1,
            Color.theme.highlightWarm2,
            Color.theme.highlightNeutral,
            Color.theme.highlightCool1
        ]
        let index = abs(text.hashValue) % options.count
        return options[index].hexString()
    }
}
