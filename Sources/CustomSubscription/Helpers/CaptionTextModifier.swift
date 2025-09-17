//
//  File name: CaptionTextModifier.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import SwiftUI

public struct CaptionTextModifier: ViewModifier {
    
    public func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

public extension View {
    /// Applies a caption text style to the view.
    func captionText() -> some View {
        modifier(CaptionTextModifier())
    }
}
