//
//  Color+Hex.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard let int = Int(hex, radix: 16) else { return nil }
        let r, g, b: Double
        switch hex.count {
        case 6: // RRGGBB
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    func hexString() -> String {
        UIColor(self).toHexString()
    }
}

extension UIColor {
    func toHexString() -> String {
        guard let components = cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
