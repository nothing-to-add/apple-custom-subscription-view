//
//  File name: PricingCardView.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import SwiftUI

public struct PricingCardView: View {
    public let title: LocalizedStringResource
    public let price: String
    public let period: LocalizedStringResource
    public let savings: LocalizedStringResource?
    public let isPopular: Bool
    public let isSelected: Bool
    
    public init(title: LocalizedStringResource, price: String, period: LocalizedStringResource, savings: LocalizedStringResource? = nil, isPopular: Bool = false, isSelected: Bool = false) {
        self.title = title
        self.price = price
        self.period = period
        self.savings = savings
        self.isPopular = isPopular
        self.isSelected = isSelected
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            if isPopular {
                Text("POPULAR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            
            Text(title)
                .font(.headline)
            
            Text(price)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(period)
                .captionText()
            
            if let savings = savings {
                Text(savings)
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.2) : (isPopular ? Color.accentColor.opacity(0.1) : Color(.systemGray6)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : (isPopular ? Color.orange.opacity(0.2) : Color.clear), lineWidth: isSelected ? 3 : 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PricingCardView(title: "Monthly",
                    price: "9.99",
                    period: "per month",
                    isPopular: false,
                    isSelected: true)
}
