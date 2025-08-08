//
//  AppFont.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

enum AppFontStyle {
    case largeTitle
    case title
    case subtitle
    case heading
    case strongBody
    case body
    case callout
    case button
    case caption
    case strongCaption
    case footnote
    case label

    var fontName: String {
        switch self {
        case .largeTitle, .title: return "Quicksand-Bold"
        case .subtitle, .caption: return "Quicksand-Medium"
        case .heading, .button, .strongBody, .strongCaption: return "Quicksand-SemiBold"
        case .body, .callout, .footnote, .label: return "Quicksand-Regular"
        }
    }

    var weight: Font.Weight {
        switch self {
        case .largeTitle: return .bold
        case .title: return .semibold
        case .subtitle, .caption: return .medium
        case .heading, .button, .strongBody, .strongCaption: return .semibold
        case .body, .callout, .footnote, .label: return .regular
        }
    }
    
    var fallbackWeight: UIFont.Weight {
        switch self {
        case .largeTitle: return .bold
        case .title: return .semibold
        case .subtitle, .caption: return .medium
        case .heading, .button, .strongBody, .strongCaption: return .semibold
        case .body, .callout, .footnote, .label: return .regular
        }
    }
    
    var size: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title: return 28
        case .subtitle: return 22
        case .heading: return 20
        case .strongBody: return 17
        case .body: return 17
        case .callout: return 16
        case .button: return 16
        case .strongCaption: return 13
        case .caption: return 13
        case .footnote: return 12
        case .label: return 11
        }
    }

    func font(size: CGFloat? = nil) -> Font {
        let fontSize = size ?? self.size
        if UIFont(name: fontName, size: fontSize) != nil {
            return .custom(fontName, size: fontSize)
        } else {
            return .system(size: fontSize, weight: weight, design: .rounded)
        }
    }

    func uiFont(size: CGFloat? = nil) -> UIFont {
        let fontSize = size ?? self.size
        return UIFont(name: fontName, size: fontSize)
        ?? .systemFont(ofSize: fontSize, weight: fallbackWeight)
    }
}
