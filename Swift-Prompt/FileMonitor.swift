import Foundation

class FileMonitor {
    private let url: URL
    private let callback: ([URL]) -> Void
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: CInt
    private var fileSnapshot: [String: Date] = [:]
    private let snapshotQueue = DispatchQueue(label: "com.swiftprompt.filemonitor.snapshot")
    private var isMonitoring = false
    private var fileDescriptorClosed = false

    init(url: URL, callback: @escaping ([URL]) -> Void) {
        self.url = url
        self.callback = callback
        self.fileDescriptor = open(url.path, O_EVTONLY)

        // SECURITY: Validate that the file descriptor was opened successfully
        guard self.fileDescriptor >= 0 else {
            SwiftLog("LOG: [ERROR] Failed to open directory for monitoring: \(url.path) (errno: \(errno))")
            return
        }

        // Take initial snapshot
        self.fileSnapshot = Self.createSnapshot(at: url)

        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .global()
        )
        self.source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let changed = self.getChangedFiles()
            if !changed.isEmpty {
                SwiftLog("FileMonitor => \(changed.count) file(s) changed")
            }
            self.callback(changed)
        }
        self.source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if !self.fileDescriptorClosed {
                close(self.fileDescriptor)
                self.fileDescriptorClosed = true
            }
        }
    }

    // SECURITY: Ensure file descriptor is closed when object is deallocated
    deinit {
        stopMonitoring()
        // If source was never created or cancel handler didn't run, close FD manually
        if !fileDescriptorClosed && fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptorClosed = true
        }
    }

    func startMonitoring() {
        // Only resume if source exists and not already monitoring
        guard source != nil, !isMonitoring else {
            if source == nil {
                SwiftLog("LOG: [WARN] Cannot start monitoring - source is nil (file descriptor open failed)")
            }
            return
        }
        source?.resume()
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        source?.cancel()
        source = nil
        isMonitoring = false
    }

    private func getChangedFiles() -> [URL] {
        let newSnapshot = Self.createSnapshot(at: url)
        var changedFiles: [URL] = []

        snapshotQueue.sync {
            // Find new or modified files
            for (path, newDate) in newSnapshot {
                if let oldDate = fileSnapshot[path] {
                    // File existed before - check if modified
                    if newDate != oldDate {
                        changedFiles.append(URL(fileURLWithPath: path))
                    }
                } else {
                    // New file
                    changedFiles.append(URL(fileURLWithPath: path))
                }
            }

            // Find deleted files
            for (path, _) in fileSnapshot {
                if newSnapshot[path] == nil {
                    changedFiles.append(URL(fileURLWithPath: path))
                }
            }

            // Update snapshot
            fileSnapshot = newSnapshot
        }

        return changedFiles
    }

    /// Creates a snapshot of all files in the directory with their modification dates
    private static func createSnapshot(at url: URL) -> [String: Date] {
        var snapshot: [String: Date] = [:]
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return snapshot
        }

        for case let fileURL as URL in enumerator {
            // Skip directories, only track files
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
               let isDirectory = resourceValues.isDirectory,
               !isDirectory,
               let modificationDate = resourceValues.contentModificationDate {
                snapshot[fileURL.path] = modificationDate
            }
        }

        return snapshot
    }
}
