//
//  ExportFormat.swift
//  Swift-Prompt
//
//  Export format handling for Swift-Prompt
//

import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case xml = "XML"
    case json = "JSON" 
    case markdown = "Markdown"
    case raw = "Raw"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .xml:
            return "XML (Structured)"
        case .json:
            return "JSON"
        case .markdown:
            return "Markdown"
        case .raw:
            return "Raw Text"
        }
    }
    
    var icon: String {
        switch self {
        case .xml:
            return "doc.text"
        case .json:
            return "curlybraces"
        case .markdown:
            return "doc.richtext"
        case .raw:
            return "doc.plaintext"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .xml:
            return "xml"
        case .json:
            return "json"
        case .markdown:
            return "md"
        case .raw:
            return "txt"
        }
    }
}

// MARK: - Export Format Manager
class ExportFormatManager {
    static func export(
        content: String,
        format: ExportFormat,
        promptData: PromptData,
        folderURL: URL?
    ) -> String {
        switch format {
        case .xml:
            return exportAsXML(content: content, promptData: promptData, folderURL: folderURL)
        case .json:
            return exportAsJSON(content: content, promptData: promptData, folderURL: folderURL)
        case .markdown:
            return exportAsMarkdown(content: content, promptData: promptData, folderURL: folderURL)
        case .raw:
            return exportAsRaw(content: content, promptData: promptData)
        }
    }
    
    // MARK: - XML Export
    private static func exportAsXML(
        content: String,
        promptData: PromptData,
        folderURL: URL?
    ) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<prompt version=\"1.0\">\n"
        
        // Add metadata section
        xml += "  <metadata>\n"
        xml += "    <timestamp>\(ISO8601DateFormatter().string(from: Date()))</timestamp>\n"
        if let folderURL = folderURL {
            xml += "    <project>\(escapeXML(folderURL.lastPathComponent))</project>\n"
        }
        
        // Parse files to get count
        let files = parseRawText(content)
        xml += "    <fileCount>\(files.count)</fileCount>\n"
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
            let language = detectLanguage(from: file.filename)
            xml += "    <file>\n"
            xml += "      <path>\(escapeXML(file.filename))</path>\n"
            xml += "      <language>\(language)</language>\n"
            xml += "      <content><![CDATA[\(file.content)]]></content>\n"
            xml += "    </file>\n"
        }
        xml += "  </files>\n"
        xml += "</prompt>"
        
        return xml
    }
    
    // MARK: - JSON Export
    private static func exportAsJSON(
        content: String,
        promptData: PromptData,
        folderURL: URL?
    ) -> String {
        let files = parseRawText(content)
        
        var jsonDict: [String: Any] = [
            "version": "1.0",
            "metadata": [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "project": folderURL?.lastPathComponent ?? "Unknown",
                "fileCount": files.count
            ]
        ]
        
        // Add tasks if any
        let validTasks = promptData.tasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validTasks.isEmpty {
            jsonDict["tasks"] = validTasks.enumerated().map { index, task in
                ["priority": index == 0 ? "high" : "normal", "content": task]
            }
        }
        
        // Add warnings if any
        let validWarnings = promptData.warnings.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validWarnings.isEmpty {
            jsonDict["warnings"] = validWarnings
        }
        
        // Add files
        jsonDict["files"] = files.map { file in
            [
                "path": file.filename,
                "language": detectLanguage(from: file.filename),
                "content": file.content
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            SwiftLog("Failed to generate JSON: \(error)")
            return "{}"
        }
    }
    
    // MARK: - Markdown Export
    private static func exportAsMarkdown(
        content: String,
        promptData: PromptData,
        folderURL: URL?
    ) -> String {
        var markdown = "# Code Export\n\n"
        
        // Add metadata
        markdown += "## Metadata\n\n"
        markdown += "- **Project**: \(folderURL?.lastPathComponent ?? "Unknown")\n"
        markdown += "- **Timestamp**: \(Date().formatted())\n"
        
        let files = parseRawText(content)
        markdown += "- **Files**: \(files.count)\n\n"
        
        // Add tasks if any
        let validTasks = promptData.tasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validTasks.isEmpty {
            markdown += "## Tasks\n\n"
            for (index, task) in validTasks.enumerated() {
                let priority = index == 0 ? "🔴 High" : "🟡 Normal"
                markdown += "- \(priority): \(task)\n"
            }
            markdown += "\n"
        }
        
        // Add warnings if any
        let validWarnings = promptData.warnings.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validWarnings.isEmpty {
            markdown += "## ⚠️ Warnings\n\n"
            for warning in validWarnings {
                markdown += "- \(warning)\n"
            }
            markdown += "\n"
        }
        
        // Add files
        markdown += "## Files\n\n"
        for file in files {
            let language = detectLanguage(from: file.filename)
            markdown += "### \(file.filename)\n\n"
            markdown += "```\(language)\n"
            markdown += file.content
            markdown += "\n```\n\n"
        }
        
        return markdown
    }
    
    // MARK: - Raw Export
    private static func exportAsRaw(content: String, promptData: PromptData) -> String {
        var raw = ""
        
        // Add tasks if any
        let validTasks = promptData.tasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validTasks.isEmpty {
            raw += "=== TASKS ===\n"
            for task in validTasks {
                raw += "- \(task)\n"
            }
            raw += "\n"
        }
        
        // Add warnings if any
        let validWarnings = promptData.warnings.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !validWarnings.isEmpty {
            raw += "=== WARNINGS ===\n"
            for warning in validWarnings {
                raw += "- \(warning)\n"
            }
            raw += "\n"
        }
        
        // Add the raw content
        raw += "=== CODE ===\n\n"
        raw += content
        
        return raw
    }
    
    // MARK: - Helper Functions
    private static func parseRawText(_ raw: String) -> [(filename: String, content: String)] {
        var files: [(filename: String, content: String)] = []
        
        let filePattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#
        
        do {
            let regex = try NSRegularExpression(pattern: filePattern, options: [])
            let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let filenameRange = Range(match.range(at: 1), in: raw),
                   let contentRange = Range(match.range(at: 2), in: raw) {
                    let filename = String(raw[filenameRange])
                    let content = String(raw[contentRange])
                    files.append((filename: filename, content: content))
                }
            }
        } catch {
            SwiftLog("Error parsing raw text: \(error)")
            files.append((filename: "aggregated.txt", content: raw))
        }
        
        return files
    }
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private static func detectLanguage(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
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
}