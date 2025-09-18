//
//  ThemeViewModifiers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

public struct DefaultBackground: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Color.theme.background.ignoresSafeArea())
    }
}

public struct ThemedBodyModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.body)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedHeadlineModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.heading)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedCaptionModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.caption)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedCalloutModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.callout)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedFootnoteModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.footnote)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedLabelModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.label)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.title)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedLargeTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.largeTitle)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedSubtitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .appFont(.subtitle)
            .foregroundColor(Color.theme.text)
    }
}

public struct ThemedCardModifier: ViewModifier {
    var blurBackground: Bool = false

    public func body(content: Content) -> some View {
        content
            .padding()
            .background(
                Group {
                    if blurBackground {
                        Color.theme.surface
                            .opacity(0.3)
                            .background(.ultraThinMaterial) // system blur layer
                    } else {
                        Color.theme.surface
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.theme.lightBorder, lineWidth: 1)
            )
    }
}

public struct ThemedBannerModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.theme.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
    }
}

public struct ThemedPrimaryButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.theme.accent)
            .foregroundColor(.white)
            .appFont(.button)
            .cornerRadius(8)
    }
}

public struct ThemedSecondaryButtonModifier: ViewModifier {
    var isEnabled = true
    public func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.clear)
            .foregroundColor(isEnabled ? Color.theme.accent : Color.theme.disabled)
            .appFont(.button)
            .cornerRadius(8)
    }
}

public struct ThemedTertiaryButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(3)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .appFont(.caption)
    }
}
