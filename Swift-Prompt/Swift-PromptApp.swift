//
//  Swift-PromptApp.swift
//  Swift-Prompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

@main
struct SwiftPromptApp: App {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var promptData = PromptData()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                .environmentObject(promptData)
                // Optional: a subtle brown accent
                .accentColor(.brown)
        }
        Settings {
            PreferencesView()
                .environmentObject(viewModel)
        }
    }
}
