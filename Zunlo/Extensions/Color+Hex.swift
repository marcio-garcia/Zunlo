//
//  Color+Hex.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/9/25.
//

//import SwiftUI
//
//extension Color {
//    
//    static var theme: Theme {
//        UITraitCollection.current.userInterfaceStyle == .dark ? Theme.dark : Theme.light
//    }
//    
//    /// Initializes a Color from a hex string. Supports `#RGB`, `#RRGGBB`, and `#RRGGBBAA` formats.
//    init?(hex: String) {
//        let cleanedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int = UInt64()
//        
//        guard Scanner(string: cleanedHex).scanHexInt64(&int) else { return nil }
//
//        let r, g, b, a: Double
//        switch cleanedHex.count {
//        case 3: // RGB (12-bit)
//            r = Double((int >> 8) & 0xF) / 15.0
//            g = Double((int >> 4) & 0xF) / 15.0
//            b = Double(int & 0xF) / 15.0
//            a = 1.0
//        case 6: // RRGGBB (24-bit)
//            r = Double((int >> 16) & 0xFF) / 255.0
//            g = Double((int >> 8) & 0xFF) / 255.0
//            b = Double(int & 0xFF) / 255.0
//            a = 1.0
//        case 8: // RRGGBBAA (32-bit)
//            r = Double((int >> 24) & 0xFF) / 255.0
//            g = Double((int >> 16) & 0xFF) / 255.0
//            b = Double((int >> 8) & 0xFF) / 255.0
//            a = Double(int & 0xFF) / 255.0
//        default:
//            return nil
//        }
//
//        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
//    }
//}
//
//
//extension Color {
//    func hexString() -> String {
//        UIColor(self).toHexString()
//    }
//}
//
//extension UIColor {
//    func toHexString() -> String {
//        guard let components = cgColor.components, components.count >= 3 else { return "#000000" }
//        let r = Int(components[0] * 255)
//        let g = Int(components[1] * 255)
//        let b = Int(components[2] * 255)
//        return String(format: "#%02X%02X%02X", r, g, b)
//    }
//}
