//
//  PromptData.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

/// Holds tasks & warnings for your final prompt (which you turn into XML).
class PromptData: ObservableObject {
    @Published var tasks: [String] = [""]
    @Published var warnings: [String] = [""]
}
