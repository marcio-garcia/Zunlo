//
//  AppFont.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

import SwiftUI
import UIKit

public struct AppFontStyle: Sendable {
    public enum Style: Sendable {
        case largeTitle
        case title
        case subtitle
        case heading
        case body
        case callout
        case button
        case caption
        case footnote
        case label
    }
    
    private let style: Style
    private let customWeight: Font.Weight?
    private let isItalic: Bool
    private let customSize: CGFloat?
    private let customTracking: CGFloat?
    
    // Public static instances for easy access
    public static let largeTitle = AppFontStyle(style: .largeTitle)
    public static let title = AppFontStyle(style: .title)
    public static let subtitle = AppFontStyle(style: .subtitle)
    public static let heading = AppFontStyle(style: .heading)
    public static let body = AppFontStyle(style: .body)
    public static let callout = AppFontStyle(style: .callout)
    public static let button = AppFontStyle(style: .button)
    public static let caption = AppFontStyle(style: .caption)
    public static let footnote = AppFontStyle(style: .footnote)
    public static let label = AppFontStyle(style: .label)
    
    private init(style: Style, weight: Font.Weight? = nil, italic: Bool = false, size: CGFloat? = nil, tracking: CGFloat? = nil) {
        self.style = style
        self.customWeight = weight
        self.isItalic = italic
        self.customSize = size
        self.customTracking = tracking
    }
    
    // MARK: - Fluent API methods
    public func weight(_ weight: Font.Weight) -> AppFontStyle {
        AppFontStyle(style: style, weight: weight, italic: isItalic, size: customSize, tracking: customTracking)
    }
    
    public func italic() -> AppFontStyle {
        AppFontStyle(style: style, weight: customWeight, italic: true, size: customSize, tracking: customTracking)
    }
    
    public func size(_ size: CGFloat) -> AppFontStyle {
        AppFontStyle(style: style, weight: customWeight, italic: isItalic, size: size, tracking: customTracking)
    }
    
    public func tracking(_ value: CGFloat) -> AppFontStyle {
        AppFontStyle(style: style, weight: customWeight, italic: isItalic, size: customSize, tracking: value)
    }
        
    // MARK: - Default values
    private var defaultWeight: Font.Weight {
        switch style {
        case .largeTitle: return .bold
        case .title: return .semibold
        case .subtitle, .caption: return .medium
        case .heading, .button: return .semibold
        case .body, .callout, .footnote, .label: return .regular
        }
    }
    
    private var defaultTracking: CGFloat {
        switch style {
        case .largeTitle: return 1.5
        case .title: return 1.2
        case .subtitle: return 0.7
        case .heading: return 0.5
        case .body: return 0.3
        case .callout: return 0.4
        case .button: return 0.6
        case .caption: return 0.2
        case .footnote: return 0.1
        case .label: return 0.2
        }
    }
    
    private var defaultSize: CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .subtitle: return 22
        case .heading: return 20
        case .body: return 17
        case .callout: return 16
        case .button: return 16
        case .caption: return 13
        case .footnote: return 12
        case .label: return 11
        }
    }
    
    // MARK: - Public properties
    public var weight: Font.Weight {
        return customWeight ?? defaultWeight
    }
    
    public var tracking: CGFloat {
        return customTracking ?? defaultTracking
    }
    
    public var size: CGFloat {
        return customSize ?? defaultSize
    }
    
    // MARK: - Nunito font mapping
    private var nunitoWeightName: String {
        switch weight {
        case .ultraLight, .thin, .light:
            return "Light"
        case .regular:
            return "Regular"
        case .medium:
            return "Medium"
        case .semibold:
            return "SemiBold"
        case .bold, .heavy, .black:
            return "Bold"
        default:
            return "Regular"
        }
    }
    
    public var fontName: String {
        let weightName = nunitoWeightName
        let italicSuffix = isItalic ? "Italic" : ""
        return "Nunito-\(weightName)\(italicSuffix)"
    }
    
    public var fallbackWeight: UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    
    // MARK: - Font creation methods
    public func font(size: CGFloat? = nil) -> Font {
        let fontSize = size ?? self.size
        if UIFont(name: fontName, size: fontSize) != nil {
            return .custom(fontName, size: fontSize)
        } else {
            let systemFont = Font.system(size: fontSize, weight: weight, design: .rounded)
            return isItalic ? systemFont.italic() : systemFont
        }
    }
    
    public func uiFont(size: CGFloat? = nil) -> UIFont {
        let fontSize = size ?? self.size
        if let customFont = UIFont(name: fontName, size: fontSize) {
            return customFont
        } else {
            let systemFont = UIFont.systemFont(ofSize: fontSize, weight: fallbackWeight)
            if isItalic {
                return systemFont.withTraits(traits: .traitItalic) ?? systemFont
            }
            return systemFont
        }
    }
    
    // MARK: - SwiftUI integration
    public func textStyle() -> some ViewModifier {
        AppFontModifier(fontStyle: self)
    }
    
    // MARK: - AttributedString methods
    public func attributedString(_ text: String, size: CGFloat? = nil) -> NSAttributedString {
        let fontSize = size ?? self.size
        let font = uiFont(size: fontSize)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: tracking
        ]
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    public func swiftUIAttributedString(_ text: String, size: CGFloat? = nil) -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.font = font(size: size)
        
        let range = attributedString.startIndex..<attributedString.endIndex
        attributedString[range].kern = tracking
        
        return attributedString
    }
    
    // MARK: - Debug helper
    public var debugFontInfo: String {
        return "Font: \(fontName), Weight: \(weight), Italic: \(isItalic), Size: \(size), Tracking: \(tracking)"
    }
}

// MARK: - SwiftUI ViewModifier
private struct AppFontModifier: ViewModifier {
    let fontStyle: AppFontStyle
    
    func body(content: Content) -> some View {
        content
            .font(fontStyle.font())
            .tracking(fontStyle.tracking)
    }
}

// MARK: - SwiftUI Extensions

extension View {
    public func appFont(_ style: AppFontStyle) -> some View {
        self.modifier(style.textStyle())
    }
}

// MARK: - UIFont Extension
private extension UIFont {
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return descriptor.map { UIFont(descriptor: $0, size: 0) }
    }
}
