//
//  DiffPreviewView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct DiffPreviewView: View {
    let fileUpdates: [LLMFileUpdate]
    let folderURL: URL?
    var onApply: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack {
            Text("Preview Changes")
                .font(.title)
                .padding(.top)
            
            if fileUpdates.isEmpty {
                Text("No file updates to preview.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(fileUpdates) { update in
                        DisclosureGroup(update.path) {
                            diffView(for: update)
                        }
                    }
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Apply", action: onApply)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
        // Add a base tan background
        .background(Color.softBeigeSecondary)
    }
}

extension DiffPreviewView {
    private func diffView(for update: LLMFileUpdate) -> some View {
        let diffLines = getDiffLines(for: update)
        return sideBySideDiffView(diffLines: diffLines)
            .frame(maxHeight: 300)
    }

    private func getDiffLines(for update: LLMFileUpdate) -> [DiffLine] {
        SwiftLog("LOG: reading old contents for: \(update.path)")
        let oldText = readOldFileContents(for: update.path)
        let newText = update.content
        return computeLineDiff(oldText: oldText, newText: newText)
    }

    private func readOldFileContents(for fileName: String) -> String {
        guard let folderURL = folderURL else {
            SwiftLog("LOG: no folderURL; returning empty.")
            return ""
        }

        // SECURITY: Reject paths containing path traversal attempts
        if fileName.contains("..") {
            SwiftLog("LOG: [SECURITY] Path traversal attempt blocked in readOldFileContents: \(fileName)")
            return ""
        }

        let fileURL = folderURL.appendingPathComponent(fileName)

        // SECURITY: Validate resolved path is within the allowed folder
        let resolvedFileURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedFolderURL = folderURL.standardizedFileURL.resolvingSymlinksInPath()
        let normalizedFolderPath = resolvedFolderURL.path.hasSuffix("/") ? resolvedFolderURL.path : resolvedFolderURL.path + "/"

        if !resolvedFileURL.path.hasPrefix(normalizedFolderPath) && resolvedFileURL.path != resolvedFolderURL.path {
            SwiftLog("LOG: [SECURITY] Path traversal blocked in diff preview: \(fileName) resolves outside folder")
            return ""
        }

        do {
            let contents = try String(contentsOf: fileURL)
            return contents
        } catch {
            SwiftLog("LOG: couldn't read \(fileName): \(error)")
            return ""
        }
    }

    private func computeLineDiff(oldText: String, newText: String) -> [DiffLine] {
        let oldLines = oldText.components(separatedBy: .newlines)
        let newLines = newText.components(separatedBy: .newlines)
        
        var result: [DiffLine] = []
        var i = 0
        var j = 0
        
        while i < oldLines.count || j < newLines.count {
            if i < oldLines.count, j < newLines.count {
                if oldLines[i] == newLines[j] {
                    result.append(DiffLine(
                        oldLine: oldLines[i],
                        newLine: newLines[j],
                        oldLineNumber: i + 1,
                        newLineNumber: j + 1,
                        changeType: .unchanged
                    ))
                    i += 1
                    j += 1
                } else {
                    result.append(DiffLine(
                        oldLine: oldLines[i],
                        newLine: nil,
                        oldLineNumber: i + 1,
                        newLineNumber: nil,
                        changeType: .removed
                    ))
                    i += 1
                    
                    result.append(DiffLine(
                        oldLine: nil,
                        newLine: newLines[j],
                        oldLineNumber: nil,
                        newLineNumber: j + 1,
                        changeType: .added
                    ))
                    j += 1
                }
            } else if i < oldLines.count {
                result.append(DiffLine(
                    oldLine: oldLines[i],
                    newLine: nil,
                    oldLineNumber: i + 1,
                    newLineNumber: nil,
                    changeType: .removed
                ))
                i += 1
            } else if j < newLines.count {
                result.append(DiffLine(
                    oldLine: nil,
                    newLine: newLines[j],
                    oldLineNumber: nil,
                    newLineNumber: j + 1,
                    changeType: .added
                ))
                j += 1
            }
        }
        return result
    }

    @ViewBuilder
    private func sideBySideDiffView(diffLines: [DiffLine]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("")
                        .frame(width: 35)
                }
                .frame(width: 200, alignment: .leading)
                
                Divider().frame(width: 1)
                
                VStack {
                    Text("Incoming")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("")
                        .frame(width: 35)
                }
                .frame(width: 200, alignment: .leading)
            }
            .padding(4)
            // changed from Color(NSColor.windowBackgroundColor) to a tan
            .background(Color.softBeigeSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
            
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(diffLines) { line in
                        HStack(alignment: .top, spacing: 0) {
                            HStack(spacing: 4) {
                                lineNumberView(line.oldLineNumber)
                                    .frame(width: 35, alignment: .trailing)
                                Text(line.oldLine ?? "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .background(backgroundColor(change: line.changeType, isNew: false))
                            }
                            
                            Divider().frame(width: 1)
                            
                            HStack(spacing: 4) {
                                lineNumberView(line.newLineNumber)
                                    .frame(width: 35, alignment: .trailing)
                                Text(line.newLine ?? "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .background(backgroundColor(change: line.changeType, isNew: true))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.vertical, 4)
            }
        }
    }
    
    private func lineNumberView(_ number: Int?) -> some View {
        Text(number.map(String.init) ?? "")
            .font(.caption2)
    }
    
    private func backgroundColor(change: DiffLine.ChangeType, isNew: Bool) -> Color {
        switch change {
        case .unchanged:
            return .clear
        case .added:
            return isNew ? Color.green.opacity(0.2) : .clear
        case .removed:
            return !isNew ? Color.red.opacity(0.2) : .clear
        }
    }
}

// MARK: - DiffLine
struct DiffLine: Identifiable {
    enum ChangeType {
        case unchanged
        case added
        case removed
    }
    
    let id = UUID()
    let oldLine: String?
    let newLine: String?
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let changeType: ChangeType
}
