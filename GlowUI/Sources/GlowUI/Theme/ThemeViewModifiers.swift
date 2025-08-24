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
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.body.font())
    }
}

public struct ThemedHeadlineModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.heading.font())
    }
}

public struct ThemedCaptionModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.caption.font())
    }
}

public struct ThemedCalloutModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.callout.font())
    }
}

public struct ThemedFootnoteModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.footnote.font())
    }
}

public struct ThemedLabelModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.label.font())
    }
}

public struct ThemedTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.title.font())
    }
}

public struct ThemedLargeTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.largeTitle.font())
    }
}

public struct ThemedSubtitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.subtitle.font())
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
            .font(AppFontStyle.button.font())
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
            .font(AppFontStyle.button.font())
            .cornerRadius(8)
    }
}

public struct ThemedTertiaryButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(3)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .font(AppFontStyle.caption.font())
    }
}
