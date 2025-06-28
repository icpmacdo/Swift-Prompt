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
                    let final = ExportFormatManager.export(
                        content: viewModel.textAreaContents,
                        format: viewModel.selectedExportFormat,
                        promptData: promptData,
                        folderURL: viewModel.folderURL
                    )
                    copyToClipboard(final)
                    showEphemeralBanner("\(viewModel.selectedExportFormat.rawValue) + tasks copied!")
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
        SwiftLog("createXML called with raw text length: \(raw.count)")
        
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<prompt version=\"1.0\">\n"
        
        // Add metadata section
        xml += "  <metadata>\n"
        xml += "    <timestamp>\(ISO8601DateFormatter().string(from: Date()))</timestamp>\n"
        if let folderURL = viewModel.folderURL {
            xml += "    <project>\(escapeXML(folderURL.lastPathComponent))</project>\n"
        }
        // Parse files early to get count
        let files = parseRawText(raw)
        SwiftLog("Parsed \(files.count) files from raw text")
        xml += "    <fileCount>\(files.count)</fileCount>\n"
        xml += "  </metadata>\n"
        
        // Add tasks section if any exist
        let validTasks = promptData.tasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validTasks.isEmpty {
            xml += "  <tasks>\n"
            for (index, task) in validTasks.enumerated() {
                let priority = index == 0 ? "high" : "normal"
                xml += "    <task priority=\"\(priority)\"><![CDATA[\(task)]]></task>\n"
            }
            xml += "  </tasks>\n"
        }
        
        // Add warnings section if any exist
        let validWarnings = promptData.warnings.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validWarnings.isEmpty {
            xml += "  <warnings>\n"
            for warning in validWarnings {
                xml += "    <warning><![CDATA[\(warning)]]></warning>\n"
            }
            xml += "  </warnings>\n"
        }
        
        // Add files section (already parsed above)
        xml += "  <files>\n"
        for file in files {
            let language = detectLanguage(from: file.filename)
            xml += "    <file>\n"
            xml += "      <path>\(escapeXML(file.filename))</path>\n"
            xml += "      <language>\(language)</language>\n"
            xml += "      <content><![CDATA[\(file.content)]]></content>\n"
            xml += "    </file>\n"
        }
        xml += "  </files>\n"
        xml += "</prompt>"
        
        SwiftLog("Generated XML length: \(xml.count)")
        SwiftLog("XML preview: \(String(xml.prefix(200)))...")
        
        return xml
    }
    
    // Helper function to escape XML special characters
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // Helper function to detect programming language from filename
    private func detectLanguage(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "java": return "java"
        case "kt": return "kotlin"
        case "m", "mm": return "objective-c"
        case "c": return "c"
        case "cpp", "cc", "cxx": return "cpp"
        case "h", "hpp": return "header"
        case "html", "htm": return "html"
        case "css", "scss", "sass": return "css"
        case "json": return "json"
        case "xml": return "xml"
        case "yaml", "yml": return "yaml"
        case "md": return "markdown"
        case "sh", "bash": return "shell"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "php": return "php"
        default: return "text"
        }
    }
    
    // Helper to parse raw text and extract individual files
    private func parseRawText(_ raw: String) -> [(filename: String, content: String)] {
        var files: [(filename: String, content: String)] = []
        
        SwiftLog("parseRawText called with text length: \(raw.count)")
        SwiftLog("Raw text preview: \(String(raw.prefix(200)))...")
        
        // Split by file markers
        let filePattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#
        
        do {
            let regex = try NSRegularExpression(pattern: filePattern, options: [])
            let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            
            SwiftLog("Found \(matches.count) regex matches")
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let filenameRange = Range(match.range(at: 1), in: raw),
                   let contentRange = Range(match.range(at: 2), in: raw) {
                    let filename = String(raw[filenameRange])
                    let content = String(raw[contentRange])
                    SwiftLog("Parsed file: \(filename) with content length: \(content.count)")
                    files.append((filename: filename, content: content))
                }
            }
        } catch {
            SwiftLog("Error parsing raw text for XML: \(error)")
            // Fallback: treat entire content as single file
            files.append((filename: "aggregated.txt", content: raw))
        }
        
        SwiftLog("parseRawText returning \(files.count) files")
        return files
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
