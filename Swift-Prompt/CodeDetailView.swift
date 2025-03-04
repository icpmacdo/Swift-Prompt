//
//  CodeDetailView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct DroppedFile: Identifiable {
    let id = UUID()
    let filename: String
    let content: String
}

struct CodeDetailView: View {
    @EnvironmentObject var viewModel: ContentViewModel
    @EnvironmentObject var promptData: PromptData

    @State private var droppedFiles: [DroppedFile] = []
    @State private var isDropTargeted: Bool = false

    @State private var showClipboardBanner = false
    @State private var clipboardBannerText = ""

    var body: some View {
        GeometryReader { geo in
            VSplitView {
                topPane
                    .frame(height: geo.size.height / 3)
                bottomPane
            }
            .frame(minWidth: 500, minHeight: 600)
            .overlay(
                VStack {
                    if showClipboardBanner {
                        Text(clipboardBannerText)
                            .padding()
                            // changed from Color.green.opacity(0.8) to:
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
        // Tan background across entire detail
        .background(Color.softBeigeSecondary)
    }
    
    private var topPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isProcessing {
                    progressSection
                }
                if viewModel.showSuccessBanner {
                    successBanner
                }
                
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
                Spacer(minLength: 10)
            }
            .padding()
        }
    }
    
    private var bottomPane: some View {
        HStack(spacing: 0) {
            leftDropZone
            Divider()
            rightQuickCopy
        }
    }
    
    // MARK: - Subviews
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(viewModel.filesProcessed),
                         total: max(Double(viewModel.totalFiles), 1))
            Text(viewModel.progressMessage)
            
            if viewModel.totalFiles > 0 {
                let percent = Double(viewModel.filesProcessed) / Double(viewModel.totalFiles) * 100
                Text("\(Int(percent))% completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("0% completed (no files).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
                
                Button("Copy Raw") {
                    copyToClipboard(viewModel.textAreaContents)
                    showEphemeralBanner("Raw code copied!")
                }
                .buttonStyle(.bordered)
                
                Button("Copy With Tasks") {
                    let final = createXML(from: viewModel.textAreaContents)
                    copyToClipboard(final)
                    showEphemeralBanner("XML + tasks copied!")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 5)
            
            TextEditor(text: $viewModel.textAreaContents)
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

            Button("Copy Commit Message") {
                copyToClipboard(viewModel.commitMessage)
                showEphemeralBanner("Commit message copied!")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var leftDropZone: some View {
        VStack {
            Text("Drag & Drop File or Folder")
                .font(.subheadline).fontWeight(.bold)
                .padding()
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDropTargeted
                          ? Color.softBeigeSecondary.opacity(0.6)
                          : Color.softBeigeSecondary.opacity(0.3))
                    .padding()
                
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 50))
                    Text("Drop a file or folder here")
                }
                .foregroundColor(.secondary)
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var rightQuickCopy: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Quick Code Copy")
                    .font(.headline)
                    .padding()
                Spacer()
                Button {
                    let allText = droppedFiles.map {
                        "// \($0.filename)\n\($0.content)\n// --- End of \($0.filename) ---\n"
                    }.joined(separator: "\n")
                    copyToClipboard(allText)
                    showEphemeralBanner("All dropped files copied!")
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .padding()
                .disabled(droppedFiles.isEmpty)
            }
            
            if droppedFiles.isEmpty {
                Text("No file content yet.\nDrop a file/folder to see its content.")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(droppedFiles) { df in
                            DisclosureGroup(df.filename) {
                                VStack(alignment: .leading) {
                                    Text(df.content)
                                        .font(.system(.body, design: .monospaced))
                                        .padding()
                                        .background(Color.softBeigeSecondary)
                                        .cornerRadius(8)
                                    
                                    Button("Copy \(df.filename)") {
                                        copyToClipboard(df.content)
                                        showEphemeralBanner("Copied \(df.filename)!")
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Functions
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, err in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }
                    
                    let fm = FileManager.default
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                            for case let fileURL as URL in enumerator {
                                var subIsDir: ObjCBool = false
                                if fm.fileExists(atPath: fileURL.path, isDirectory: &subIsDir), !subIsDir.boolValue {
                                    self.readDroppedFile(fileURL)
                                }
                            }
                        }
                    } else {
                        self.readDroppedFile(url)
                    }
                }
            }
        }
        return true
    }
    
    private func readDroppedFile(_ fileURL: URL) {
        do {
            let fileData = try Data(contentsOf: fileURL)
            if let text = String(data: fileData, encoding: .utf8) {
                DispatchQueue.main.async {
                    droppedFiles.append(.init(filename: fileURL.lastPathComponent, content: text))
                }
            }
        } catch {
            SwiftLog("Error reading dropped file => \(error.localizedDescription)")
        }
    }
    
    private func createXML(from raw: String) -> String {
        // same code as before, just your existing method
        // ...
        return ""
    }
    
    private func copyToClipboard(_ text: String) {
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
}
