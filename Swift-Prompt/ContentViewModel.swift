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
    @Published var currentError: SwiftPromptError?
    @Published var showingError = false
    @Published var selectedExportFormat: ExportFormat = .xml
    
    // For controlling which file types to load
    @Published var availableFileTypes: [String] = []
    @Published var selectedFileTypes: Set<String> = []  // persisted between sessions
    
    @Published private(set) var filesCopied = 0
    @Published private(set) var totalFiles = 0
    @Published private(set) var filesProcessed = 0
    
    // For showing the folder tree
    @Published var folderTree: FolderNode? = nil
    
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
        let excluded = [".git", "node_modules", "dist", "build"]
        return excluded.contains(url.lastPathComponent)
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
    
    private func countCodeFiles(in folderURL: URL) async throws -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: [.skipsHiddenFiles])
        else {
            throw NSError(domain: "Could not create enumerator", code: 1)
        }
        
        let excludedDirs = ["node_modules", ".git", "dist", "build"]
        var count = 0
        for case let fileURL as URL in enumerator {
            let vals = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if let isDir = vals.isDirectory, isDir {
                if excludedDirs.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            if let isFile = vals.isRegularFile, isFile {
                let ext = fileURL.pathExtension.lowercased()
                if selectedFileTypes.contains("*") || selectedFileTypes.contains(ext) {
                    count += 1
                }
            }
        }
        return count
    }
    
    private func aggregateCodeFiles(in folderURL: URL) async throws -> String {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: [.skipsHiddenFiles])
        else {
            throw NSError(domain: "Could not create enumerator", code: 2)
        }
        
        let excludedDirs = ["node_modules", ".git", "dist", "build"]
        
        // First pass: collect all files to process
        var filesToProcess: [URL] = []
        for case let fileURL as URL in enumerator {
            let vals = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if vals.isDirectory == true, excludedDirs.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            if vals.isRegularFile == true {
                let ext = fileURL.pathExtension.lowercased()
                if selectedFileTypes.contains("*") || selectedFileTypes.contains(ext) {
                    filesToProcess.append(fileURL)
                }
            }
        }
        
        // Update total files count
        await MainActor.run {
            self.totalFiles = filesToProcess.count
            self.filesProcessed = 0
        }
        
        // Process files concurrently
        let concurrentLimit = 10 // Process up to 10 files at once
        var results: [(index: Int, content: String)] = []
        
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, fileURL) in filesToProcess.enumerated() {
                // Limit concurrent tasks
                if index >= concurrentLimit {
                    if let result = await group.next() {
                        if let content = result.1 {
                            results.append((result.0, content))
                        }
                    }
                }
                
                group.addTask { [weak self] in
                    guard let self = self else { return (index, nil) }
                    
                    do {
                        let text = try self.readFileContent(at: fileURL)
                        var fileContent = ""
                        
                        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                        if let first = lines.first, first.trimmingCharacters(in: .whitespaces).hasPrefix("// \(fileURL.lastPathComponent)") {
                            fileContent = text
                        } else {
                            fileContent = "// \(fileURL.lastPathComponent)\n\n"
                            fileContent += text
                        }
                        fileContent += "\n\n// --- End of \(fileURL.lastPathComponent) ---\n\n"
                        
                        await MainActor.run {
                            self.filesCopied += 1
                            self.filesProcessed += 1
                            let percentage = Int((Double(self.filesProcessed) / Double(self.totalFiles)) * 100)
                            self.progressMessage = "Processing files... \(percentage)% (\(self.filesProcessed)/\(self.totalFiles))"
                        }
                        
                        return (index, fileContent)
                    } catch let error as SwiftPromptError {
                        SwiftLog("LOG: [ERROR] \(error.localizedDescription)")
                        await MainActor.run {
                            self.handleError(error)
                        }
                        return (index, nil)
                    } catch {
                        SwiftLog("LOG: [ERROR] reading \(fileURL.lastPathComponent): \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }
            
            // Collect remaining results
            for await result in group {
                if let content = result.1 {
                    results.append((result.0, content))
                }
            }
        }
        
        // Sort results by index to maintain file order
        results.sort { $0.index < $1.index }
        
        // Combine all file contents
        var combined = ""
        for result in results {
            combined += result.content
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
    
    // MARK: - Error Handling
    func handleError(_ error: SwiftPromptError) {
        currentError = error
        showingError = true
        
        // Log error
        SwiftLog(
            "LOG: [ERROR] \(error.localizedDescription)",
            context: "ContentViewModel"
        )
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
    
    // MARK: - Safe File Operations
    func readFileContent(at url: URL) throws -> String {
        do {
            // Security check for path traversal
            if let folderPath = folderURL?.path {
                let normalizedPath = url.path
                let normalizedFolderPath = folderPath
                
                // Check for path traversal attempts
                if normalizedPath.contains("../") || normalizedPath.contains("..\\") {
                    throw SwiftPromptError.pathTraversalAttempt(path: url.path)
                }
                
                // Ensure file is within selected folder
                if !normalizedPath.hasPrefix(normalizedFolderPath) {
                    throw SwiftPromptError.pathTraversalAttempt(path: url.path)
                }
            }
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw SwiftPromptError.fileNotFound(path: url.path)
            }
            
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            // Check file size (10MB limit)
            if fileSize > 10_000_000 {
                throw SwiftPromptError.fileTooLarge(path: url.path, size: fileSize)
            }
            
            // Try to read with UTF-8 first
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                // Try alternative encodings
                if let content = try? String(contentsOf: url, encoding: .macOSRoman) {
                    return content
                }
                if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                    return content
                }
                throw SwiftPromptError.fileReadError(path: url.path, underlying: error)
            }
        } catch let error as SwiftPromptError {
            throw error
        } catch {
            throw SwiftPromptError.fileReadError(path: url.path, underlying: error)
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
                self.selectedFileTypes = found
            }
        }
    }
}
