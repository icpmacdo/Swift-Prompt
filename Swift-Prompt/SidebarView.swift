//
//  SidebarView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ContentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            folderSelectionSection
            fileTypesSelectionSection
            exportFormatSection
            actionsSection
            folderTreeSection
            Spacer()
        }
        .padding()
        // Soft tan background
        .background(Color.softBeigeSecondary)
        .frame(minWidth: 300)
    }
    
    private var headerSection: some View {
        VStack {
            Image(systemName: "doc.on.clipboard")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.accentColor)
            Text("Swift Prompt")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Aggregate code files from a folder or by dragging them below.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var folderSelectionSection: some View {
        Section(header: Text("Selected Folder").font(.subheadline).fontWeight(.bold)) {
            HStack {
                TextField("Selected Folder",
                          text: Binding(get: { viewModel.folderURL?.path ?? "" },
                                        set: { _ in }))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)

                Button("Browse") {
                    SwiftLog("LOG: Sidebar => user tapped Browse.")
                    viewModel.selectFolder()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
        }
    }
    
    private var fileTypesSelectionSection: some View {
        Section(header: Text("Select File Types to Include")
                    .font(.subheadline)
                    .fontWeight(.bold)) {
            MultiSelectDropdown(
                title: "Select File Types",
                options: viewModel.availableFileTypes,
                selectedOptions: $viewModel.selectedFileTypes
            )
        }
    }
    
    private var exportFormatSection: some View {
        Section(header: Text("Export Format")
                    .font(.subheadline)
                    .fontWeight(.bold)) {
            Picker("Format", selection: $viewModel.selectedExportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    HStack {
                        Image(systemName: format.icon)
                        Text(format.displayName)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.segmented)
            .help("Choose the format for exporting your code")
        }
    }
    
    private var actionsSection: some View {
        Section(header: Text("Task List, Warnings & Actions")
                    .font(.subheadline)
                    .fontWeight(.bold)) {
            SidebarPromptFormattingView()
            Divider()
            Button(role: .destructive) {
                viewModel.clearAll()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var folderTreeSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Folder Tree")
                .font(.subheadline)
                .fontWeight(.bold)
            if let rootNode = viewModel.folderTree {
                FolderTreeView(rootNode: rootNode)
                    .frame(minHeight: 200)
            } else {
                Text("No folder selected yet.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .environmentObject(ContentViewModel())
    }
}
