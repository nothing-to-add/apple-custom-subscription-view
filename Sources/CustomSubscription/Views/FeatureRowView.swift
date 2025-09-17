//
//  File name: FeatureRowView.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import SwiftUI

public struct FeatureRowView: View {
    public let feature: PremiumFeature
    
    public init(feature: PremiumFeature) {
        self.feature = feature
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(feature.description)
                    .captionText()
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    FeatureRowView(feature: PremiumFeature(
        icon: "square.and.arrow.up.fill",
        title: "Export & Share",
        description: "Share with loved ones"
    ))
}
