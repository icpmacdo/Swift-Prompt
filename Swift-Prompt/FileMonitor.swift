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
        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: self.fileDescriptor,
            eventMask: .write,
            queue: .global()
        )
        self.source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let changed = self.getChangedFiles()
            if !changed.isEmpty {
                SwiftLog("FileMonitor => changes: \(changed)")
            }
            self.callback(changed)
        }
        self.source?.setCancelHandler {
            close(self.fileDescriptor)
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
        // Minimal example, always returns [url]
        return [url]
    }
}
