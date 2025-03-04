//
//  MessageClientView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI
import AppKit

// MARK: - LLMFileUpdate Model
struct LLMFileUpdate: Codable {
    let fileName: String
    let code: String
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
                                let errorMsg = "Could not write \(update.fileName): \(error.localizedDescription)"
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
        let fileBaseName = URL(fileURLWithPath: update.fileName).deletingPathExtension().lastPathComponent
        let fileExt = URL(fileURLWithPath: update.fileName).pathExtension
        let safeFilename = "\(fileBaseName)-\(timestamp).\(fileExt)"

        let destination = swiftPromptFolder.appendingPathComponent(safeFilename)

        do {
            try update.code.write(to: destination, atomically: true, encoding: .utf8)
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

        var sanitizedFilename = update.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
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

        try update.code.write(to: destination, atomically: true, encoding: .utf8)
    }
}

// MARK: - Parsing LLM Code Blocks
extension MessageClientView {
    private func parseFileUpdates(from fullText: String) -> [LLMFileUpdate] {
        SwiftLog("LOG: parseFileUpdates => text length: \(fullText.count)")

        // 1) Try JSON
        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("["),
           let data = fullText.data(using: .utf8) {
            do {
                let jsonUpdates = try JSONDecoder().decode([LLMFileUpdate].self, from: data)
                return jsonUpdates
            } catch {
                SwiftLog("LOG: JSON decode failed => \(error.localizedDescription). Falling back to regex.")
            }
        }

        // Simple code block extraction based on markdown-style code fences
        var final: [LLMFileUpdate] = []
        let codeBlockPattern = #"```(?:swift)?\s*(?:\w+\.swift)?\s*([\w/\-\.]+\.swift)(?:\s*|\n)([\s\S]*?)```"#
        let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [])
        
        if let regex = regex {
            let range = NSRange(fullText.startIndex..<fullText.endIndex, in: fullText)
            let matches = regex.matches(in: fullText, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let fileNameRange = Range(match.range(at: 1), in: fullText),
                   let codeRange = Range(match.range(at: 2), in: fullText) {
                    
                    let fileName = String(fullText[fileNameRange])
                    let code = String(fullText[codeRange])
                    
                    let update = LLMFileUpdate(fileName: fileName.trimmingCharacters(in: .whitespacesAndNewlines),
                                              code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                    final.append(update)
                }
            }
        }
        
        return final
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

