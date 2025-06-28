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
        .commands {
            // File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    viewModel.selectFolder()
                }
                .keyboardShortcut("O", modifiers: .command)
            }
            
            // Edit menu commands
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy Code") {
                    copyCode()
                }
                .keyboardShortcut("C", modifiers: .command)
                .disabled(viewModel.textAreaContents.isEmpty)
                
                Button("Refresh") {
                    refreshContent()
                }
                .keyboardShortcut("R", modifiers: .command)
                .disabled(viewModel.folderURL == nil)
            }
            
            // View menu commands
            CommandGroup(after: .sidebar) {
                Button("Search...") {
                    // This will trigger the search functionality when implemented
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSearch"), object: nil)
                }
                .keyboardShortcut("F", modifiers: .command)
            }
        }
        
        Settings {
            PreferencesView()
                .environmentObject(viewModel)
        }
    }
    
    private func copyCode() {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        let content = ExportFormatManager.export(
            content: viewModel.textAreaContents,
            format: viewModel.selectedExportFormat,
            promptData: promptData,
            folderURL: viewModel.folderURL
        )
        
        pb.setString(content, forType: .string)
    }
    
    private func refreshContent() {
        if let url = viewModel.folderURL {
            viewModel.loadFiles(from: url)
        }
    }
}
