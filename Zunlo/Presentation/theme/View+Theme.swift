//
//  View+Theme.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/17/25.
//

import SwiftUI

extension View {
    func themedLargeTitle() -> some View {
        self.modifier(ThemedLargeTitleModifier())
    }
    
    func themedTitle() -> some View {
        self.modifier(ThemedTitleModifier())
    }
    
    func themedSubtitle() -> some View {
        self.modifier(ThemedSubtitleModifier())
    }
    
    func themedHeadline() -> some View {
        self.modifier(ThemedHeadlineModifier())
    }
    
    func themedBody() -> some View {
        self.modifier(ThemedBodyModifier())
    }
    
    func themedCallout() -> some View {
        self.modifier(ThemedCalloutModifier())
    }
    
    func themedCaption() -> some View {
        self.modifier(ThemedCaptionModifier())
    }
    
    func themedFootnote() -> some View {
        self.modifier(ThemedFootnoteModifier())
    }
    
    func themedLabel() -> some View {
        self.modifier(ThemedLabelModifier())
    }

    func themedCard() -> some View {
        self.modifier(ThemedCardModifier())
    }
    
    func themedBanner() -> some View {
        self.modifier(ThemedBannerModifier())
    }

    func themedPrimaryButton() -> some View {
        self.modifier(ThemedPrimaryButtonModifier())
    }
    
    func themedSecondaryButton(isEnabled: Bool = true) -> some View {
        self.modifier(ThemedSecondaryButtonModifier(isEnabled: isEnabled))
    }
    
    func themedTertiaryButton() -> some View {
        self.modifier(ThemedTertiaryButtonModifier())
    }
}

// MARK: - Example Usage

// Text("Welcome Back").themedText()
// RoundedRectangle(cornerRadius: 16).fill(Color.theme.surface)
//     .overlay(Text("Add Task").themedText())
// VStack { ... }.themedCard()
// Button("Save") { ... }.themedButton()
//
// Text("Important").font(AppFont.heading())
// Text("Details").font(AppFont.caption(size: 12))

//Text("Welcome").themedText()
//VStack {
//    Text("Today").font(AppFont.heading())
//    Text("No tasks yet").font(AppFont.caption())
//}
//.themedCard()
//
//Button("Save") { ... }.themedButton()

