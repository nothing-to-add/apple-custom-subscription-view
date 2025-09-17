//
//  File name: PremiumFeature.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 16/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import Foundation

public struct PremiumFeature {
    public let icon: String
    public let title: LocalizedStringResource
    public let description: LocalizedStringResource
    
    public init(icon: String, title: LocalizedStringResource, description: LocalizedStringResource) {
        self.icon = icon
        self.title = title
        self.description = description
    }
}
