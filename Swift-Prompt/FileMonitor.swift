import Foundation

class FileMonitor {
    private let url: URL
    private let callback: ([URL]) -> Void
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: CInt

    init(url: URL, callback: @escaping ([URL]) -> Void) {
        self.url = url
        self.callback = callback
        self.fileDescriptor = open(url.path, O_EVTONLY)

        if self.fileDescriptor < 0 {
            SwiftLog("FileMonitor [ERROR]: Error opening file descriptor for \(url.path). Error: \(String(cString: strerror(errno)))")
            self.source = nil
            return
        }
        
        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.fileDescriptor,
            eventMask: .write,
            queue: .global()
        )
        
        self.source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let changed = self.getChangedFiles()
            // It's useful to log when the event handler fires and what it detected.
            // Avoid logging if 'changed' is empty, or adjust logging as needed.
            if !changed.isEmpty {
                 SwiftLog("FileMonitor => event for \(self.url.path), detected changes: \(changed.map { $0.lastPathComponent })")
            }
            self.callback(changed)
        }
        
        self.source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                SwiftLog("FileMonitor => closed file descriptor for \(self.url.path)")
            }
        }
    }

    func startMonitoring() {
        source?.resume()
    }

    func stopMonitoring() {
        source?.cancel()
        source = nil
    }

    private func getChangedFiles() -> [URL] {
        // This is a basic implementation. It reports that *something* in the monitored
        // directory changed, but not *which specific file(s)*. For more precise change
        // detection (e.g., to avoid reloading all files when only one changes),
        // a more advanced approach like directory snapshot comparison or deeper
        // integration with FSEvents would be necessary. Currently, any write event
        // in the directory will result in this monitor reporting the root URL as changed.
        return [url]
    }
}
