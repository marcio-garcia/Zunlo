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
    let disabled: Color

    // Add more semantic roles as needed

    static let light = Theme(
        accent: Color(hex: "#F6A192")!, // Coral Peach
        background: Color(hex: "#FAF4F2")!, // Porcelain Pink
        surface: Color(hex: "#FDF1E7")!, // Light Sand
        text: Color(hex: "#44403C")!, // Warm Graphite
        secondaryText: Color(hex: "#6B4C46")!, // Slightly lighter warm gray
        success: Color(hex: "#C9E4CA")!, // Mint Cream
        border: Color(hex: "#DAB7AB")!, // Dusty Blush
        disabled: Color.gray
    )

    static let dark = Theme(
        accent: Color(hex: "#E98578")!,
        background: Color(hex: "#2B2623")!,
        surface: Color(hex: "#3B3532")!,
        text: Color(hex: "#EAE2DF")!,
        secondaryText: Color(hex: "#C9BBB5")!,
        success: Color(hex: "#98C9A3")!,
        border: Color(hex: "#5A4944")!,
        disabled: Color.gray
    )
}
