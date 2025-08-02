//
//  ThemeViewModifiers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

struct DefaultBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.theme.background.ignoresSafeArea())
    }
}

struct ThemedBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.body.font())
    }
}

struct ThemedHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.heading.font())
    }
}

struct ThemedCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.caption.font())
    }
}

struct ThemedCalloutModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.callout.font())
    }
}

struct ThemedFootnoteModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.footnote.font())
    }
}

struct ThemedLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.label.font())
    }
}

struct ThemedTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.title.font())
    }
}

struct ThemedLargeTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.largeTitle.font())
    }
}

struct ThemedSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFontStyle.subtitle.font())
    }
}

struct ThemedCardModifier: ViewModifier {
    var blurBackground: Bool = false

    func body(content: Content) -> some View {
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

struct ThemedBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
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

struct ThemedPrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.theme.accent)
            .foregroundColor(.white)
            .font(AppFontStyle.button.font())
            .cornerRadius(8)
    }
}

struct ThemedSecondaryButtonModifier: ViewModifier {
    var isEnabled = true
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.clear)
            .foregroundColor(isEnabled ? Color.theme.accent : Color.theme.disabled)
            .font(AppFontStyle.button.font())
            .cornerRadius(8)
    }
}

struct ThemedTertiaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(3)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .font(AppFontStyle.caption.font())
    }
}
