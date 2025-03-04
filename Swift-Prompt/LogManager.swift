import Foundation
import Combine

/// A singleton class that collects log messages.
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: String = ""
    
    func append(_ message: String) {
        DispatchQueue.main.async {
            self.logs.append(message + "\n")
        }
    }
}

func SwiftLog(_ message: String) {
    print(message)
    LogManager.shared.append(message)
}
