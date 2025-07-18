//
//  AppFont.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

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
