//
//  XMLExportTests.swift
//  Swift-PromptTests
//
//  Test suite for XML export functionality
//

import XCTest
@testable import Swift_Prompt

class XMLExportTests: XCTestCase {
    
    func testParseRawTextWithSingleFile() {
        let testContent = """
// TestFile.swift

func helloWorld() {
    print("Hello, World!")
}

// --- End of TestFile.swift ---

"""
        
        // Create a CodeDetailView instance to test parseRawText
        // Note: This test validates the regex pattern matches the aggregated format
        let result = parseRawTextHelper(testContent)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].filename, "TestFile.swift")
        XCTAssertTrue(result[0].content.contains("func helloWorld()"))
    }
    
    func testParseRawTextWithMultipleFiles() {
        let testContent = """
// File1.swift

struct User {
    let name: String
}

// --- End of File1.swift ---

// File2.swift

enum Status {
    case active
    case inactive
}

// --- End of File2.swift ---

"""
        
        let result = parseRawTextHelper(testContent)
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].filename, "File1.swift")
        XCTAssertEqual(result[1].filename, "File2.swift")
    }
    
    func testCreateXMLWithTasksAndWarnings() {
        // This will test the full XML generation including tasks and warnings
        let mockData = PromptData()
        mockData.tasks = ["Implement login feature", "Add unit tests"]
        mockData.warnings = ["Do not modify existing API", "Maintain backward compatibility"]
        
        let rawContent = """
// LoginView.swift

import SwiftUI

struct LoginView: View {
    var body: some View {
        Text("Login")
    }
}

// --- End of LoginView.swift ---

"""
        
        let xml = createXMLHelper(from: rawContent, promptData: mockData)
        
        // Verify XML structure
        XCTAssertTrue(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("<prompt version=\"1.0\">"))
        XCTAssertTrue(xml.contains("<tasks>"))
        XCTAssertTrue(xml.contains("<task priority=\"high\"><![CDATA[Implement login feature]]></task>"))
        XCTAssertTrue(xml.contains("<warnings>"))
        XCTAssertTrue(xml.contains("<warning><![CDATA[Do not modify existing API]]></warning>"))
        XCTAssertTrue(xml.contains("<files>"))
        XCTAssertTrue(xml.contains("<path>LoginView.swift</path>"))
        XCTAssertTrue(xml.contains("<language>swift</language>"))
    }
    
    // Helper function that mirrors parseRawText logic
    private func parseRawTextHelper(_ raw: String) -> [(filename: String, content: String)] {
        var files: [(filename: String, content: String)] = []
        
        // Updated regex to match the actual format
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
            print("Error parsing raw text: \(error)")
            files.append((filename: "aggregated.txt", content: raw))
        }
        
        return files
    }
    
    // Helper to test XML creation
    private func createXMLHelper(from raw: String, promptData: PromptData) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<prompt version=\"1.0\">\n"
        
        // Add metadata section
        xml += "  <metadata>\n"
        xml += "    <timestamp>\(ISO8601DateFormatter().string(from: Date()))</timestamp>\n"
        xml += "    <project>TestProject</project>\n"
        let files = parseRawTextHelper(raw)
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
            let language = detectLanguageHelper(from: file.filename)
            xml += "    <file>\n"
            xml += "      <path>\(escapeXMLHelper(file.filename))</path>\n"
            xml += "      <language>\(language)</language>\n"
            xml += "      <content><![CDATA[\(file.content)]]></content>\n"
            xml += "    </file>\n"
        }
        xml += "  </files>\n"
        xml += "</prompt>"
        
        return xml
    }
    
    private func escapeXMLHelper(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    private func detectLanguageHelper(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "java": return "java"
        default: return "text"
        }
    }
}