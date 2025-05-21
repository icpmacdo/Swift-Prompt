//
//  ContentViewModel.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI
import Combine
import AppKit

class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var progressMessage = ""
    @Published var textAreaContents = ""
    @Published var folderURL: URL? = nil
    @Published var successMessage = ""
    @Published var showSuccessBanner = false
    @Published var errorMessage = ""
    @Published var showErrorAlert = false
    @Published var commitMessage: String = ""
    
    // For controlling which file types to load
    @Published var availableFileTypes: [String] = []
    @Published var selectedFileTypes: Set<String> = []  // persisted between sessions
    
    @Published private(set) var filesCopied = 0
    @Published private(set) var totalFiles = 0
    @Published private(set) var filesProcessed = 0
    
    // For showing the folder tree
    @Published var folderTree: FolderNode? = nil
    
    // Static constant for excluded directory names
    private static let excludedDirectoryNames = ["node_modules", ".git", "dist", "build"]
    // Static constant for common code file extensions to prioritize for default selection
    private static let commonCodeFileExtensions: Set<String> = ["swift", "h", "m", "cpp", "c", "js", "ts", "py", "java", "rb", "go", "cs", "kt", "html", "css", "json", "xml", "sql", "sh", "pl", "rs", "php", "dart", "md"]
    
    private var fileMonitor: FileMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Load previously saved selected file types from UserDefaults.
        if let savedFileTypes = UserDefaults.standard.array(forKey: "SelectedFileTypes") as? [String] {
            selectedFileTypes = Set(savedFileTypes)
        }
        
        // Persist any changes to selectedFileTypes automatically.
        $selectedFileTypes
            .sink { newSelection in
                UserDefaults.standard.set(Array(newSelection), forKey: "SelectedFileTypes")
            }
            .store(in: &cancellables)
        
        // Watch for changes to folderURL to trigger file loading and monitoring.
        $folderURL
            .sink { [weak self] newURL in
                guard let self = self else { return }
                if let folderURL = newURL {
                    SwiftLog("LOG: folderURL changed => \(folderURL.path)")
                    self.startMonitoringFolder(folderURL)
                    Task {
                        await self.updateAvailableFileTypes(for: folderURL)
                        await MainActor.run {
                            // If no selection has been made yet, default to all discovered file types.
                            if self.selectedFileTypes.isEmpty {
                                self.selectedFileTypes = Set(self.availableFileTypes)
                            }
                        }
                        self.loadFiles(from: folderURL)
                        self.buildFolderTree(from: folderURL)
                    }
                } else {
                    SwiftLog("LOG: folderURL cleared => stop monitoring.")
                    self.fileMonitor?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Folder Selection with Security Scoping
    func selectFolder() {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a Folder"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.showsHiddenFiles = false
        dialog.prompt = "Select Folder for Reading and Writing"
        
        if dialog.runModal() == .OK, let url = dialog.url {
            let startedAccessing = url.startAccessingSecurityScopedResource()
            if startedAccessing {
                SwiftLog("LOG: Started accessing security-scoped resource at \(url.path)")
            }
            
            if !FileManager.default.isWritableFile(atPath: url.path) {
                SwiftLog("LOG: [WARN] Selected folder is not writable: \(url.path)")
                DispatchQueue.main.async {
                    self.errorMessage = "The selected folder doesn't have write permissions. You may have read-only access, or need to grant additional permissions."
                    self.showErrorAlert = true
                }
            }
            
            // Create a security-scoped bookmark.
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "LastAccessedFolderBookmark")
                SwiftLog("LOG: Created security-scoped bookmark for folder")
            } catch {
                SwiftLog("LOG: [ERROR] Failed to create bookmark: \(error)")
            }
            
            self.folderURL = url
        } else {
            SwiftLog("LOG: user canceled folder selection.")
        }
    }
    
    func restorePreviousFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "LastAccessedFolderBookmark") else {
            return
        }
        
        do {
            var isStale = false
            let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                SwiftLog("LOG: Bookmark is stale, will need to select folder again")
                return
            }
            
            if resolvedURL.startAccessingSecurityScopedResource() {
                SwiftLog("LOG: Restored access to previous folder: \(resolvedURL.path)")
                self.folderURL = resolvedURL
            }
        } catch {
            SwiftLog("LOG: [ERROR] Failed to resolve bookmark: \(error)")
        }
    }
    
    // MARK: - Building Folder Tree
    func buildFolderTree(from url: URL) {
        Task {
            let rootNode = await createFolderNode(for: url)
            await MainActor.run {
                self.folderTree = rootNode
            }
        }
    }
    
    private func createFolderNode(for url: URL) async -> FolderNode {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let nodeName = url.lastPathComponent
        var node = FolderNode(name: nodeName, url: url, isDirectory: isDir.boolValue)
        
        if isDir.boolValue {
            do {
                let childURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                var children: [FolderNode] = []
                for cURL in childURLs {
                    if shouldExclude(cURL) { continue }
                    let childNode = await createFolderNode(for: cURL)
                    children.append(childNode)
                }
                // Directories first, files second.
                children.sort { ($0.isDirectory ? 0 : 1) < ($1.isDirectory ? 0 : 1) }
                node.children = children
            } catch {
                SwiftLog("LOG: [ERROR] Could not read directory => \(error.localizedDescription)")
            }
        }
        return node
    }
    
    private func shouldExclude(_ url: URL) -> Bool {
        return ContentViewModel.excludedDirectoryNames.contains(url.lastPathComponent)
    }
    
    // MARK: - File Loading and Aggregation
    func loadFiles(from folder: URL) {
        Task {
            await MainActor.run {
                self.isProcessing = true
                self.progressMessage = "Preparing..."
                self.filesCopied = 0
                self.filesProcessed = 0
                self.totalFiles = 0
                self.textAreaContents = ""
            }
            
            do {
                let count = try await countCodeFiles(in: folder)
                await MainActor.run {
                    self.totalFiles = count
                    if count == 0 {
                        self.errorMessage = "No readable code files found in that folder."
                        self.showErrorAlert = true
                        self.isProcessing = false
                        return
                    }
                }
                
                let combined = try await aggregateCodeFiles(in: folder)
                await MainActor.run {
                    self.textAreaContents = combined
                    self.successMessage = "Successfully loaded \(self.filesCopied) file(s)."
                    self.showSuccessBanner = true
                    self.isProcessing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { self.showSuccessBanner = false }
                    }
                }
            } catch {
                SwiftLog("LOG: [ERROR] loadFiles => \(error.localizedDescription)")
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - File Enumeration Helper
    private func enumerateAccessibleFiles(in folderURL: URL, selectedFileTypes: Set<String>, excludedDirectories: [String]) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            throw NSError(domain: "FileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create file enumerator for \(folderURL.path)"])
        }
        
        var accessibleFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                if excludedDirectories.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue // Skip directories from being added to the list
            }
            
            if let isRegularFile = resourceValues.isRegularFile, isRegularFile {
                let fileExtension = fileURL.pathExtension.lowercased()
                if selectedFileTypes.contains("*") || selectedFileTypes.contains(fileExtension) {
                    accessibleFiles.append(fileURL)
                }
            }
        }
        return accessibleFiles
    }
    
    private func countCodeFiles(in folderURL: URL) async throws -> Int {
        let files = try enumerateAccessibleFiles(in: folderURL, selectedFileTypes: selectedFileTypes, excludedDirectories: ContentViewModel.excludedDirectoryNames)
        return files.count
    }
    
    private func aggregateCodeFiles(in folderURL: URL) async throws -> String {
        let filesToProcess = try enumerateAccessibleFiles(in: folderURL, selectedFileTypes: selectedFileTypes, excludedDirectories: ContentViewModel.excludedDirectoryNames)
        
        var combined = ""
        for fileURL in filesToProcess {
            do {
                let data = try Data(contentsOf: fileURL)
                let text = String(data: data, encoding: .utf8) ?? ""
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                if let first = lines.first, first.trimmingCharacters(in: .whitespaces).hasPrefix("// \(fileURL.lastPathComponent)") {
                    combined += text
                } else {
                    combined += "// \(fileURL.lastPathComponent)\n\n"
                    combined += text
                }
                combined += "\n\n// --- End of \(fileURL.lastPathComponent) ---\n\n"
                
                await MainActor.run {
                    self.filesCopied += 1
                    self.filesProcessed += 1
                    self.progressMessage = "Processing \(self.filesProcessed) of \(self.totalFiles)..."
                }
            } catch {
                SwiftLog("LOG: [ERROR] reading \(fileURL.lastPathComponent): \(error.localizedDescription)")
                // Optionally, decide if one error should stop all processing or just skip the file
            }
        }
        return combined
    }
    
    // MARK: - Folder Monitoring
    private func startMonitoringFolder(_ folderURL: URL) {
        fileMonitor?.stopMonitoring()
        fileMonitor = FileMonitor(url: folderURL) { [weak self] changed in
            guard let self = self else { return }
            SwiftLog("FileMonitor => changed: \(changed)")
            self.loadFiles(from: folderURL)
        }
        fileMonitor?.startMonitoring()
    }
    
    // MARK: - Clear All Data
    func clearAll() {
        SwiftLog("LOG: clearAll => resetting.")
        Task {
            await MainActor.run {
                self.isProcessing = false
                self.progressMessage = ""
                self.textAreaContents = ""
                self.folderURL = nil
                self.successMessage = ""
                self.showSuccessBanner = false
                self.errorMessage = ""
                self.showErrorAlert = false
                self.filesCopied = 0
                self.totalFiles = 0
                self.filesProcessed = 0
                self.folderTree = nil
                self.selectedFileTypes = Set(self.availableFileTypes)
            }
        }
    }
    
}

// MARK: - Update Available File Types Extension
extension ContentViewModel {
    func updateAvailableFileTypes(for folderURL: URL) async {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        let standardExtensions: Set<String> = [
            "swift", "h", "m", "cpp", "c", "js", "ts", "py", "java",
            "rb", "go", "cs", "kt", "html", "css", "json", "xml",
            "sql", "sh", "bat", "pl", "rs", "php", "dart"
        ]
        var found: Set<String> = []
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               vals.isDirectory == false {
                let ext = fileURL.pathExtension.lowercased()
                if !ext.isEmpty, standardExtensions.contains(ext) {
                    found.insert(ext)
                }
            }
        }
        await MainActor.run {
            self.availableFileTypes = Array(found).sorted()
            SwiftLog("LOG: discovered file types => \(self.availableFileTypes)")
            if self.selectedFileTypes.isEmpty {
                let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
                if !preferredSelection.isEmpty {
                    self.selectedFileTypes = preferredSelection
                    SwiftLog("LOG: auto-selected common file types => \(preferredSelection)")
                } else {
                    self.selectedFileTypes = found // Fallback to all found if no common types are present
                    SwiftLog("LOG: no common file types found, auto-selected all discovered types => \(found)")
                }
            }
        }
    }
}
