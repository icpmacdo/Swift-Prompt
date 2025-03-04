//
//  ContentView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI
import AppKit

extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    func prependingIndent(_ spaces: Int) -> String {
        let indent = String(repeating: " ", count: spaces)
        return self
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    @EnvironmentObject var promptData: PromptData

    @State private var isDropTargeted: Bool = false
    @State private var droppedFileURLs: [URL] = []
    @State private var droppedFileContents: String = ""

    @State private var showClipboardBanner: Bool = false
    @State private var clipboardBannerText: String = ""

    var body: some View {
        NavigationView {
            sidebarColumn
            mainColumn
        }
        .navigationViewStyle(.columns)
        .frame(minWidth: 800, minHeight: 600)
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            VStack {
                if showClipboardBanner {
                    Text(clipboardBannerText)
                        .padding()
                        .background(Color.softBeigeSecondary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .top))
                }
                Spacer()
            }
            .padding(),
            alignment: .top
        )
    }

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            folderSelectionSection
            fileTypesSection
            actionsSection
            folderTreeSection
            Spacer()
        }
        .padding()
        .frame(minWidth: 300)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { toggleSidebar() } label: {
                    Image(systemName: "sidebar.left")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.clearAll()
                    droppedFileURLs.removeAll()
                    droppedFileContents = ""
                    promptData.tasks = [""]
                    promptData.warnings = [""]
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear all")
            }
        }
        .background(Color.softBeigeSecondary)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
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
        .padding(.vertical, 10)
    }

    private var folderSelectionSection: some View {
        Section {
            HStack {
                TextField("Selected Folder", text: Binding(
                    get: { viewModel.folderURL?.path ?? "" },
                    set: { _ in }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
                Button("Browse") {
                    viewModel.selectFolder()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
        } header: {
            Text("Selected Folder")
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }

    private var fileTypesSection: some View {
        Section {
            MultiSelectDropdown(
                title: "Select File Types",
                options: viewModel.availableFileTypes,
                selectedOptions: $viewModel.selectedFileTypes
            )
        } header: {
            Text("Select File Types to Include")
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }

    private var actionsSection: some View {
        Section {
            Text("Goals / Warnings / Toggles:")
                .font(.callout)
            Toggle("Wrap in XML", isOn: .constant(true))
            Divider()
            Button(role: .destructive) {
                viewModel.clearAll()
                droppedFileURLs.removeAll()
                droppedFileContents = ""
                promptData.tasks = [""]
                promptData.warnings = [""]
            } label: {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        } header: {
            Text("Task List, Warnings & Actions")
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }

    private var folderTreeSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Folder Tree")
                .font(.subheadline)
                .fontWeight(.bold)
            if let root = viewModel.folderTree {
                FolderTreeView(rootNode: root)
                    .frame(minHeight: 200)
            } else {
                Text("No folder selected yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var mainColumn: some View {
        GeometryReader { geo in
            VSplitView {
                topPane
                    .frame(height: viewModel.folderURL == nil ? nil : geo.size.height / 3)
                bottomPane
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color.softBeigeSecondary)
        }
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 600)
    }

    private var topPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isProcessing { progressSection }
                if viewModel.showSuccessBanner { successBanner }
                
                if !viewModel.textAreaContents.isEmpty {
                    loadedFileContentsSection
                } else {
                    Text("No files loaded yet.")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.softBeigeSecondary)
                        )
                }
                
                if !viewModel.commitMessage.isEmpty {
                    commitMessageSection
                }
                Spacer().frame(height: 10)
            }
            .padding()
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(viewModel.filesProcessed),
                         total: Double(viewModel.totalFiles))
            Text(viewModel.progressMessage)
            let percent = Double(viewModel.filesProcessed) / Double(viewModel.totalFiles) * 100
            Text(String(format: "%.0f%% completed", percent))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var successBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(viewModel.successMessage)
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.2))
        .cornerRadius(8)
    }

    private var loadedFileContentsSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Whole codebase quick copy:")
                    .font(.headline)
                Spacer()
                Button {
                    copyToClipboard(text: viewModel.textAreaContents)
                    showEphemeralBanner("Raw file contents copied!")
                } label: {
                    Label("Copy Raw", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    let finalText = createFinalExportText(from: viewModel.textAreaContents)
                    copyToClipboard(text: finalText)
                    showEphemeralBanner("File contents + tasks copied!")
                } label: {
                    Label("Copy With Tasks", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 5)
            
            TextEditor(text: $viewModel.textAreaContents)
                .font(.body)
                .padding(5)
                .frame(minHeight: 200)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.softBeigeSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary, lineWidth: 1)
                )
        }
    }

    private var commitMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $viewModel.commitMessage)
                .frame(minHeight: 100)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.softBeigeSecondary)
                )
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 1))
            Button {
                copyToClipboard(text: viewModel.commitMessage)
                showEphemeralBanner("Commit message copied!")
            } label: {
                Label("Copy Commit Message", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    private var bottomPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag & Drop Files into the Text Area Below")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.top)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDropTargeted
                          ? Color.softBeigeSecondary.opacity(0.6)
                          : Color.softBeigeSecondary.opacity(0.3))
                    .padding()
                
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("Drag files here")
                        .foregroundColor(.secondary)
                    
                    if !droppedFileURLs.isEmpty {
                        Divider().padding(.vertical, 8)
                        ForEach(droppedFileURLs, id: \.self) { url in
                            Text(url.lastPathComponent)
                                .font(.footnote)
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFileDrop(providers: providers)
            }
            .frame(minHeight: 150)

            Divider().padding(.vertical, 8)

            VStack(alignment: .leading) {
                HStack {
                    Text("Dropped File Contents:")
                        .font(.headline)
                    Spacer()
                    Button {
                        let finalText = createFinalExportText(from: droppedFileContents)
                        copyToClipboard(text: finalText)
                        showEphemeralBanner("Dropped file contents copied as XML!")
                    } label: {
                        Label("Copy With Tasks", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                TextEditor(text: $droppedFileContents)
                    .font(.body)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.softBeigeSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, lineWidth: 1)
                    )
                    .frame(minHeight: 200)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    // MARK: - File Drop Handler
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let data = item as? Data,
                       let droppedURL = URL(dataRepresentation: data, relativeTo: nil) {
                        do {
                            let fileData = try Data(contentsOf: droppedURL)
                            if let fileText = String(data: fileData, encoding: .utf8) {
                                DispatchQueue.main.async {
                                    self.droppedFileURLs.append(droppedURL)
                                    self.droppedFileContents += "\n// \(droppedURL.lastPathComponent)\n\n" + fileText + "\n// --- End of \(droppedURL.lastPathComponent) ---\n\n"
                                }
                            }
                        } catch {
                            SwiftLog("Error reading dropped file: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        return true
    }

    private func createFinalExportText(from raw: String) -> String {
        // Your XML conversion code here.
        return raw
    }

    private func copyToClipboard(text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func showEphemeralBanner(_ msg: String) {
        clipboardBannerText = msg
        withAnimation { showClipboardBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showClipboardBanner = false }
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ContentViewModel())
            .environmentObject(PromptData())
    }
}
