//
//  MessageClientView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI
import AppKit

// MARK: - LLMFileUpdate Model
struct LLMFileUpdate: Codable, Identifiable {
    let id = UUID()
    let path: String
    let content: String
    let operation: FileOperation = .update
    
    // Legacy support
    init(fileName: String, code: String) {
        self.path = fileName
        self.content = code
    }
    
    init(path: String, content: String, operation: FileOperation = .update) {
        self.path = path
        self.content = content
    }
    
    // Codable support for legacy JSON format
    enum CodingKeys: String, CodingKey {
        case path = "fileName"
        case content = "code"
    }
}

enum FileOperation {
    case update
    case create
    case delete
}

// MARK: - Language Pattern
struct LanguagePattern {
    let language: String
    let extensions: [String]
    let aliases: [String]
}

// MARK: - Enhanced Response Parser
class EnhancedResponseParser {
    static let languagePatterns: [LanguagePattern] = [
        LanguagePattern(language: "swift", extensions: ["swift"], aliases: []),
        LanguagePattern(language: "javascript", extensions: ["js", "jsx"], aliases: ["js", "javascript"]),
        LanguagePattern(language: "typescript", extensions: ["ts", "tsx"], aliases: ["ts", "typescript"]),
        LanguagePattern(language: "python", extensions: ["py"], aliases: ["python", "py"]),
        LanguagePattern(language: "java", extensions: ["java"], aliases: []),
        LanguagePattern(language: "kotlin", extensions: ["kt", "kts"], aliases: ["kotlin"]),
        LanguagePattern(language: "html", extensions: ["html", "htm"], aliases: []),
        LanguagePattern(language: "css", extensions: ["css", "scss", "sass"], aliases: []),
        LanguagePattern(language: "json", extensions: ["json"], aliases: []),
        LanguagePattern(language: "xml", extensions: ["xml"], aliases: []),
        LanguagePattern(language: "yaml", extensions: ["yaml", "yml"], aliases: []),
        LanguagePattern(language: "shell", extensions: ["sh", "bash"], aliases: ["bash", "sh", "shell"]),
        LanguagePattern(language: "ruby", extensions: ["rb"], aliases: ["ruby", "rb"]),
        LanguagePattern(language: "go", extensions: ["go"], aliases: ["go", "golang"]),
        LanguagePattern(language: "rust", extensions: ["rs"], aliases: ["rust", "rs"]),
        LanguagePattern(language: "cpp", extensions: ["cpp", "cc", "cxx", "c++"], aliases: ["cpp", "c++"]),
        LanguagePattern(language: "c", extensions: ["c", "h"], aliases: [])
    ]
    
    static func parseResponse(_ response: String) -> [LLMFileUpdate] {
        var updates: [LLMFileUpdate] = []
        
        // Try multiple patterns to extract code blocks
        let patterns = [
            // Pattern 1: Standard markdown with language
            #"```(\w+)?\s*\n([^\n]+\.\w+)?\s*\n([\s\S]*?)```"#,
            
            // Pattern 2: Filename on first line after fence
            #"```(\w+)?\s*\n([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
            
            // Pattern 3: Filename as comment
            #"```(\w+)?\s*\n(?://|#|--)\s*([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
            
            // Pattern 4: Combined language:filename
            #"```(\w+):([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
            
            // Pattern 5: No language, just filename
            #"```\s*\n([^\n]+\.\w+)\s*\n([\s\S]*?)```"#
        ]
        
        for pattern in patterns {
            updates.append(contentsOf: extractWithPattern(pattern, from: response))
        }
        
        // Remove duplicates based on filename
        var seen = Set<String>()
        return updates.filter { update in
            guard !seen.contains(update.path) else { return false }
            seen.insert(update.path)
            return true
        }
    }
    
    private static func extractWithPattern(_ pattern: String, from text: String) -> [LLMFileUpdate] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return []
        }
        
        var updates: [LLMFileUpdate] = []
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let update = parseMatch(match, in: text) {
                updates.append(update)
            }
        }
        
        return updates
    }
    
    private static func parseMatch(_ match: NSTextCheckingResult, in text: String) -> LLMFileUpdate? {
        let nsString = text as NSString
        
        // Extract components based on capture groups
        var language: String?
        var filename: String?
        var content: String?
        
        // Flexible extraction based on number of groups
        for i in 1..<match.numberOfRanges {
            let range = match.range(at: i)
            guard range.location != NSNotFound else { continue }
            
            let captured = nsString.substring(with: range)
            
            // Detect what this capture group contains
            if captured.contains(".") && captured.count < 100 {
                // Likely a filename
                filename = captured
            } else if captured.count < 20 && languagePatterns.contains(where: { $0.aliases.contains(captured.lowercased()) || $0.language == captured.lowercased() }) {
                // Likely a language identifier
                language = captured
            } else if captured.count > 20 {
                // Likely the content
                content = captured
            }
        }
        
        // Validate we have minimum required data
        guard let file = filename, let code = content else {
            return nil
        }
        
        // If no language detected, try to infer from extension
        if language == nil {
            let ext = (file as NSString).pathExtension
            language = languagePatterns.first { $0.extensions.contains(ext.lowercased()) }?.language
        }
        
        return LLMFileUpdate(
            path: file.trimmingCharacters(in: .whitespacesAndNewlines),
            content: code,
            operation: .update
        )
    }
}

struct MessageClientView: View {
    @EnvironmentObject var viewModel: ContentViewModel

    @State private var llmUpdatesText: String = ""
    @State private var showCopyBanner: Bool = false
    @State private var showApplyBanner: Bool = false
    @State private var applyBannerText: String = ""
    @State private var isDropTargeted: Bool = false
    @State private var pendingFileUpdates: [LLMFileUpdate] = []

    var body: some View {
        VSplitView {
            AnyView(topView)
            AnyView(bottomView)
        }
        .background(Color.softBeigeSecondary)
    }

    // Extract the top portion as a computed property.
    private var topView: some View {
        VStack(alignment: .leading, spacing: 20) {
            updatesSection

            if !pendingFileUpdates.isEmpty {
                Text("Preview Changes")
                    .font(.title2)
                    .padding(.top)

                DiffPreviewView(
                    fileUpdates: pendingFileUpdates,
                    folderURL: viewModel.folderURL,
                    onApply: {
                        SwiftLog("LOG: User tapped Apply. Attempting to write each LLMFileUpdate to disk...")
                        var successfullyWritten = 0

                        for update in pendingFileUpdates {
                            do {
                                try writeFileUpdate(update)
                                successfullyWritten += 1
                            } catch {
                                let errorMsg = "Could not write \(update.path): \(error.localizedDescription)"
                                SwiftLog("LOG: [ERROR] \(errorMsg)")
                                // Fall back to Documents folder
                                DispatchQueue.main.async {
                                    self.saveFileWithoutSavePanel(update)
                                }
                            }
                        }

                        pendingFileUpdates = []
                        if successfullyWritten > 0 {
                            SwiftLog("LOG: Wrote \(successfullyWritten) file(s).")
                            showApplySuccessBanner("Wrote \(successfullyWritten) file(s) to disk.")
                        }
                    },
                    onCancel: {
                        SwiftLog("LOG: User tapped Cancel. Clearing pending updates.")
                        pendingFileUpdates = []
                    }
                )
            }

            Spacer()
        }
        .padding()
        .overlay(ephemeralBanners, alignment: .top)
    }

    // Extract the bottom portion as a computed property.
    private var bottomView: some View {
        ConsoleLogView()
            .frame(minHeight: 200)
    }
}

// MARK: - UI Subviews
extension MessageClientView {
    private var updatesSection: some View {
        Group {
            Text("Paste LLM's Updated Code Blocks Below")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDropTargeted ? Color.softBeigeSecondary.opacity(0.6)
                                         : Color.softBeigeSecondary.opacity(0.3))

                TextEditor(text: $llmUpdatesText)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        self.handleFileDrop(providers: providers)
                    }
                    .frame(minHeight: 200)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary, lineWidth: 1)
            )

            HStack {

                Spacer()

                Button(action: clearUpdates) {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)

                Button(action: applyUpdates) {
                    Label("Parse & Apply Updates", systemImage: "wrench.and.screwdriver")
                }
                .buttonStyle(.borderedProminent)
                .disabled(llmUpdatesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var ephemeralBanners: some View {
        VStack {
            if showCopyBanner {
                Text("Copied to clipboard!")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.softBeigeSecondary)
                    .cornerRadius(8)
                    .transition(.move(edge: .top))
            }
            if showApplyBanner {
                Text(applyBannerText)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.softBeigeSecondary)
                    .cornerRadius(8)
                    .transition(.move(edge: .top))
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Actions
extension MessageClientView {
    private func applyUpdates() {
        SwiftLog("LOG: Attempting to parse LLM updates from llmUpdatesText.")
        let updates = parseFileUpdates(from: llmUpdatesText)
        guard !updates.isEmpty else {
            showApplySuccessBanner("No code blocks found.")
            return
        }
        pendingFileUpdates = updates
    }

    private func clearUpdates() {
        llmUpdatesText = ""
    }

    private func showApplySuccessBanner(_ text: String) {
        applyBannerText = text
        withAnimation {
            showApplyBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                self.showApplyBanner = false
            }
        }
    }

    private func saveFileWithoutSavePanel(_ update: LLMFileUpdate) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let swiftPromptFolder = documentsURL.appendingPathComponent("SwiftPrompt Exports")

        do {
            try FileManager.default.createDirectory(at: swiftPromptFolder,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            SwiftLog("LOG: [ERROR] Failed to create SwiftPrompt folder: \(error)")
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileBaseName = URL(fileURLWithPath: update.path).deletingPathExtension().lastPathComponent
        let fileExt = URL(fileURLWithPath: update.path).pathExtension
        let safeFilename = "\(fileBaseName)-\(timestamp).\(fileExt)"

        let destination = swiftPromptFolder.appendingPathComponent(safeFilename)

        do {
            try update.content.write(to: destination, atomically: true, encoding: .utf8)
            SwiftLog("LOG: [SUCCESS] Wrote file to Documents folder: \(destination.path)")

            self.showApplySuccessBanner("Saved to Documents/SwiftPrompt Exports/\(safeFilename)")

            NSWorkspace.shared.selectFile(destination.path, inFileViewerRootedAtPath: swiftPromptFolder.path)
        } catch {
            SwiftLog("LOG: [ERROR] Failed to write to Documents folder: \(error)")
            self.showApplySuccessBanner("Error: \(error.localizedDescription)")
        }
    }

    private func writeFileUpdate(_ update: LLMFileUpdate) throws {
        guard let folder = viewModel.folderURL else {
            throw NSError(domain: "SwiftPromptErrorDomain", code: 100, userInfo: [
                NSLocalizedDescriptionKey: "No folder selected."
            ])
        }

        var sanitizedFilename = update.path.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitizedFilename.isEmpty {
            throw NSError(domain: "SwiftPromptErrorDomain", code: 101, userInfo: [
                NSLocalizedDescriptionKey: "Cannot write file with empty filename."
            ])
        }

        var targetFolder = folder
        let components = sanitizedFilename.components(separatedBy: "/")
        let actualFilename = components.last ?? sanitizedFilename

        if components.count > 1 {
            let subdirComponents = components.dropLast()
            for component in subdirComponents {
                if component == ".." || component == "." { continue }
                targetFolder = targetFolder.appendingPathComponent(component)
            }
            try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            sanitizedFilename = actualFilename
        }

        let destination = targetFolder.appendingPathComponent(sanitizedFilename)
        let fm = FileManager.default

        if fm.fileExists(atPath: destination.path) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let backupURL = destination.appendingPathExtension("backup-\(timestamp)")
            do {
                try fm.copyItem(at: destination, to: backupURL)
                SwiftLog("LOG: Backed up original file to \(backupURL.lastPathComponent)")
            } catch {
                SwiftLog("LOG: [WARN] Could not backup file.")
            }
        }

        try update.content.write(to: destination, atomically: true, encoding: .utf8)
    }
}

// MARK: - Parsing LLM Code Blocks
extension MessageClientView {
    private func parseFileUpdates(from fullText: String) -> [LLMFileUpdate] {
        SwiftLog("LOG: parseFileUpdates => text length: \(fullText.count)")
        
        // Use EnhancedResponseParser for code block extraction
        let updates = EnhancedResponseParser.parseResponse(fullText)
        
        if updates.isEmpty {
            // Try JSON parsing as fallback
            if let jsonUpdates = tryParseJSON(fullText) {
                return jsonUpdates
            }
            
            SwiftLog("LOG: No updates found in the response")
        }
        
        return updates
    }
    
    private func tryParseJSON(_ text: String) -> [LLMFileUpdate]? {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("["),
              let data = text.data(using: .utf8) else {
            return nil
        }
        
        do {
            let jsonUpdates = try JSONDecoder().decode([LLMFileUpdate].self, from: data)
            return jsonUpdates
        } catch {
            SwiftLog("LOG: JSON decode failed => \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Drag & Drop
extension MessageClientView {
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    guard let data = item as? Data,
                          let droppedURL = URL(dataRepresentation: data, relativeTo: nil)
                    else { return }

                    let fm = FileManager.default
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: droppedURL.path, isDirectory: &isDir), isDir.boolValue {
                        if let enumerator = fm.enumerator(at: droppedURL,
                                                          includingPropertiesForKeys: [URLResourceKey.isRegularFileKey],
                                                          options: [.skipsHiddenFiles]) {
                            for case let fileURL as URL in enumerator {
                                var subIsDir: ObjCBool = false
                                if fm.fileExists(atPath: fileURL.path, isDirectory: &subIsDir), !subIsDir.boolValue {
                                    self.appendFileContents(fileURL)
                                }
                            }
                        }
                    } else {
                        self.appendFileContents(droppedURL)
                    }
                }
            }
        }
        return true
    }

    private func appendFileContents(_ fileURL: URL) {
        do {
            let fileData = try Data(contentsOf: fileURL)
            if let fileText = String(data: fileData, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.llmUpdatesText += "\n\n// \(fileURL.lastPathComponent)\n\n"
                    self.llmUpdatesText += fileText
                    self.llmUpdatesText += "\n\n// --- End of \(fileURL.lastPathComponent) ---\n\n"
                }
            }
        } catch {
            SwiftLog("LOG: [ERROR] reading dropped file: \(error.localizedDescription)")
        }
    }
}

