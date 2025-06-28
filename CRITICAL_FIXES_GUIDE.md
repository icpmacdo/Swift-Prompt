# Critical Fixes Implementation Guide

## Priority 1: Fix XML Export (Day 1-2)

### Step 1: Locate and Understand the Problem
The `createXML()` function in `ContentViewModel.swift` (line ~285) currently returns an empty string.

### Step 2: Implement Working XML Export

```swift
func createXML() -> String {
    var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    xml += "<prompt version=\"1.0\">\n"
    
    // Add metadata section
    xml += "  <metadata>\n"
    xml += "    <timestamp>\(ISO8601DateFormatter().string(from: Date()))</timestamp>\n"
    xml += "    <fileCount>\(files.count)</fileCount>\n"
    if let folderURL = selectedFolderURL {
        xml += "    <project>\(escapeXML(folderURL.lastPathComponent))</project>\n"
    }
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
    
    // Add files section
    xml += "  <files>\n"
    for file in files {
        let language = detectLanguage(from: file.path.pathExtension)
        xml += "    <file>\n"
        xml += "      <path>\(escapeXML(file.path.path))</path>\n"
        xml += "      <language>\(language)</language>\n"
        xml += "      <content><![CDATA[\(file.content)]]></content>\n"
        xml += "    </file>\n"
    }
    xml += "  </files>\n"
    xml += "</prompt>"
    
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

// Helper function to detect programming language
private func detectLanguage(from extension: String) -> String {
    switch `extension`.lowercased() {
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
```

### Step 3: Update the Export Function
In `getCodeText()` or wherever the export is triggered:

```swift
func exportContent(format: ExportFormat = .xml) -> String {
    switch format {
    case .xml:
        return createXML()
    case .json:
        return createJSON()
    case .markdown:
        return createMarkdown()
    case .raw:
        return getRawText()
    }
}
```

### Step 4: Test XML Export
Create test cases to verify:
1. Valid XML structure
2. Special characters properly escaped
3. CDATA sections for content
4. Tasks and warnings included
5. Empty sections handled gracefully

## Priority 2: Multi-Language Response Parser (Day 3)

### Step 1: Refactor the Parser
Location: `MessageClientView.swift` around line 204

```swift
struct LanguagePattern {
    let language: String
    let extensions: [String]
    let aliases: [String]
}

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
        return updates.uniqued(by: \.path)
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
```

### Step 2: Update parseMessage Function

```swift
private func parseMessage() {
    let updates = EnhancedResponseParser.parseResponse(message)
    
    if updates.isEmpty {
        // Try JSON parsing as fallback
        if let jsonUpdates = tryParseJSON(message) {
            llmFileUpdates = jsonUpdates
            return
        }
        
        // Show error if no updates found
        showParsingError = true
    } else {
        llmFileUpdates = updates
    }
}
```

## Priority 3: Error Handling Framework (Day 4-5)

### Step 1: Create Error Types
Create new file: `SwiftPromptError.swift`

```swift
import Foundation

enum SwiftPromptError: LocalizedError {
    case fileAccessDenied(path: String)
    case fileNotFound(path: String)
    case fileReadError(path: String, underlying: Error)
    case fileWriteError(path: String, underlying: Error)
    case xmlGenerationFailed(reason: String)
    case responseParsingFailed(reason: String)
    case folderSelectionCancelled
    case invalidFileFormat(path: String)
    case fileTooLarge(path: String, size: Int)
    case securityScopedResourceError
    case backupFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let path, let error):
            return "Failed to read \(path): \(error.localizedDescription)"
        case .fileWriteError(let path, let error):
            return "Failed to write \(path): \(error.localizedDescription)"
        case .xmlGenerationFailed(let reason):
            return "XML generation failed: \(reason)"
        case .responseParsingFailed(let reason):
            return "Failed to parse AI response: \(reason)"
        case .folderSelectionCancelled:
            return "Folder selection was cancelled"
        case .invalidFileFormat(let path):
            return "Invalid file format: \(path)"
        case .fileTooLarge(let path, let size):
            return "File too large: \(path) (\(size) bytes)"
        case .securityScopedResourceError:
            return "Failed to access security-scoped resource"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileAccessDenied:
            return "Check file permissions and try again"
        case .fileNotFound:
            return "Verify the file exists and the path is correct"
        case .fileReadError, .fileWriteError:
            return "Check disk space and file permissions"
        case .xmlGenerationFailed:
            return "Try selecting fewer files or check for special characters"
        case .responseParsingFailed:
            return "Ensure the AI response contains properly formatted code blocks"
        case .folderSelectionCancelled:
            return "Select a folder to continue"
        case .invalidFileFormat:
            return "Only text-based files are supported"
        case .fileTooLarge:
            return "Try excluding large files or increase the size limit in preferences"
        case .securityScopedResourceError:
            return "Re-select the folder to restore access"
        case .backupFailed:
            return "Check disk space and permissions for the backup directory"
        }
    }
}
```

### Step 2: Add Error Handling to Views

```swift
// In ContentViewModel
@Published var currentError: SwiftPromptError?
@Published var showingError = false

func handleError(_ error: SwiftPromptError) {
    currentError = error
    showingError = true
    
    // Log error
    SwiftLog.log(
        level: .error,
        message: error.localizedDescription,
        context: "ContentViewModel"
    )
}

// Add to views
.alert("Error", isPresented: $viewModel.showingError) {
    Button("OK") {
        viewModel.showingError = false
    }
    if let suggestion = viewModel.currentError?.recoverySuggestion {
        Button("Help") {
            // Show help or recovery options
        }
    }
} message: {
    VStack {
        Text(viewModel.currentError?.localizedDescription ?? "Unknown error")
        if let suggestion = viewModel.currentError?.recoverySuggestion {
            Text(suggestion)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### Step 3: Wrap File Operations

```swift
// Example: Safe file reading
func readFileContent(at url: URL) throws -> String {
    do {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SwiftPromptError.fileNotFound(path: url.path)
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int ?? 0
        
        // Check file size (10MB limit)
        if fileSize > 10_000_000 {
            throw SwiftPromptError.fileTooLarge(path: url.path, size: fileSize)
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    } catch let error as SwiftPromptError {
        throw error
    } catch {
        throw SwiftPromptError.fileReadError(path: url.path, underlying: error)
    }
}
```

## Testing Strategy

### Unit Tests for XML Generation

```swift
func testXMLGenerationWithTasksAndWarnings() throws {
    // Setup
    let viewModel = ContentViewModel()
    viewModel.promptData.tasks = ["Refactor UserManager", "Add error handling"]
    viewModel.promptData.warnings = ["Maintain iOS 14 compatibility"]
    viewModel.files = [
        FileContent(path: URL(fileURLWithPath: "/test/file.swift"), content: "let x = 1")
    ]
    
    // Act
    let xml = viewModel.createXML()
    
    // Assert
    XCTAssertTrue(xml.contains("<?xml version=\"1.0\""))
    XCTAssertTrue(xml.contains("<task priority=\"high\"><![CDATA[Refactor UserManager]]></task>"))
    XCTAssertTrue(xml.contains("<task priority=\"normal\"><![CDATA[Add error handling]]></task>"))
    XCTAssertTrue(xml.contains("<warning><![CDATA[Maintain iOS 14 compatibility]]></warning>"))
    XCTAssertTrue(xml.contains("<path>/test/file.swift</path>"))
    XCTAssertTrue(xml.contains("<language>swift</language>"))
    XCTAssertTrue(xml.contains("<![CDATA[let x = 1]]>"))
}
```

### Integration Test for Parser

```swift
func testMultiLanguageResponseParsing() throws {
    let response = """
    Here are the updated files:
    
    ```swift
    ContentView.swift
    struct ContentView: View {
        var body: some View {
            Text("Hello")
        }
    }
    ```
    
    ```javascript
    // app.js
    function main() {
        console.log("Hello");
    }
    ```
    
    ```python
    main.py
    def main():
        print("Hello")
    ```
    """
    
    let updates = EnhancedResponseParser.parseResponse(response)
    
    XCTAssertEqual(updates.count, 3)
    XCTAssertEqual(updates[0].path, "ContentView.swift")
    XCTAssertEqual(updates[1].path, "app.js")
    XCTAssertEqual(updates[2].path, "main.py")
}
```

## Verification Checklist

Before marking each fix as complete:

### XML Export
- [ ] Valid XML structure generated
- [ ] Special characters properly escaped
- [ ] Tasks and warnings included
- [ ] Empty sections handled gracefully
- [ ] Large files handled without memory issues
- [ ] CDATA sections properly formatted

### Multi-Language Parser
- [ ] Parses Swift files ✓
- [ ] Parses JavaScript/TypeScript files
- [ ] Parses Python files
- [ ] Parses Java files
- [ ] Parses web files (HTML/CSS)
- [ ] Handles multiple formats in one response
- [ ] Gracefully handles malformed blocks

### Error Handling
- [ ] All file operations wrapped in try-catch
- [ ] User-friendly error messages
- [ ] Recovery suggestions provided
- [ ] Errors logged appropriately
- [ ] No app crashes on errors
- [ ] Alert dialogs working correctly

## Next Steps

After completing these critical fixes:
1. Run full test suite
2. Manual testing with real projects
3. Performance profiling
4. Update documentation
5. Prepare for beta testing