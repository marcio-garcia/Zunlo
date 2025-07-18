//
//  ThemeViewModifiers.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

struct ThemedBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.body())
    }
}

struct ThemedHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.heading())
    }
}

struct ThemedCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.caption())
    }
}

struct ThemedCalloutModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.callout())
    }
}

struct ThemedFootnoteModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.footnote())
    }
}

struct ThemedLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.label())
    }
}

struct ThemedTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.title())
    }
}

struct ThemedLargeTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.largeTitle())
    }
}

struct ThemedSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.theme.text)
            .font(AppFont.subtitle())
    }
}

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
            .font(AppFont.button())
            .cornerRadius(8)
    }
}

struct ThemedSecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .font(AppFont.button())
            .cornerRadius(8)
    }
}

struct ThemedTertiaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(3)
            .background(Color.clear)
            .foregroundColor(Color.theme.accent)
            .font(AppFont.caption())
    }
}
