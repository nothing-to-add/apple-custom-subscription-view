//
//  File name: StringLocalizationExtension.swift
//  Project name: apple-custom-subscription-view
//  Workspace name: apple-custom-subscription-view
//
//  Created by: nothing-to-add on 19/09/2025
//  Using Swift 6.0
//  Copyright (c) 2023 nothing-to-add
//

import Foundation

public extension String {
    var localized: String { 
        NSLocalizedString(self, bundle: .module, comment: "")
    }
}
