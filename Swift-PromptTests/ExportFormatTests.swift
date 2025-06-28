//
//  ExportFormatTests.swift
//  Swift-PromptTests
//
//  Test suite for export format functionality
//

import Testing
import SwiftUI
@testable import Swift_Prompt

struct ExportFormatTests {
    
    // MARK: - Export Format Enum Tests
    
    @Test func testExportFormatProperties() async throws {
        // Test XML format
        let xmlFormat = ExportFormat.xml
        #expect(xmlFormat.displayName == "XML (Structured)")
        #expect(xmlFormat.icon == "doc.text")
        #expect(xmlFormat.fileExtension == "xml")
        
        // Test JSON format
        let jsonFormat = ExportFormat.json
        #expect(jsonFormat.displayName == "JSON")
        #expect(jsonFormat.icon == "curlybraces")
        #expect(jsonFormat.fileExtension == "json")
        
        // Test Markdown format
        let markdownFormat = ExportFormat.markdown
        #expect(markdownFormat.displayName == "Markdown")
        #expect(markdownFormat.icon == "doc.richtext")
        #expect(markdownFormat.fileExtension == "md")
        
        // Test Raw format
        let rawFormat = ExportFormat.raw
        #expect(rawFormat.displayName == "Raw Text")
        #expect(rawFormat.icon == "doc.plaintext")
        #expect(rawFormat.fileExtension == "txt")
    }
    
    @Test func testAllCasesAvailable() async throws {
        let allCases = ExportFormat.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.xml))
        #expect(allCases.contains(.json))
        #expect(allCases.contains(.markdown))
        #expect(allCases.contains(.raw))
    }
    
    // MARK: - Export Manager Tests
    
    @Test func testXMLExport() async throws {
        let promptData = PromptData()
        promptData.tasks = ["Task 1", "Task 2"]
        promptData.warnings = ["Warning 1"]
        
        let content = """
        // test.swift

        let x = 1

        // --- End of test.swift ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .xml,
            promptData: promptData,
            folderURL: URL(fileURLWithPath: "/test/project")
        )
        
        // Verify XML structure
        #expect(exported.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(exported.contains("<prompt version=\"1.0\">"))
        #expect(exported.contains("<metadata>"))
        #expect(exported.contains("<project>project</project>"))
        #expect(exported.contains("<fileCount>1</fileCount>"))
        #expect(exported.contains("<tasks>"))
        #expect(exported.contains("<task priority=\"high\"><![CDATA[Task 1]]></task>"))
        #expect(exported.contains("<task priority=\"normal\"><![CDATA[Task 2]]></task>"))
        #expect(exported.contains("<warnings>"))
        #expect(exported.contains("<warning><![CDATA[Warning 1]]></warning>"))
        #expect(exported.contains("<files>"))
        #expect(exported.contains("<path>test.swift</path>"))
        #expect(exported.contains("<language>swift</language>"))
        #expect(exported.contains("<content><![CDATA[let x = 1]]></content>"))
    }
    
    @Test func testJSONExport() async throws {
        let promptData = PromptData()
        promptData.tasks = ["Build feature"]
        promptData.warnings = ["Check compatibility"]
        
        let content = """
        // script.js

        console.log("test");

        // --- End of script.js ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .json,
            promptData: promptData,
            folderURL: URL(fileURLWithPath: "/test/myapp")
        )
        
        // Parse JSON to verify structure
        guard let data = exported.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #expect(Bool(false))
            return
        }
        
        #expect(json["version"] as? String == "1.0")
        
        if let metadata = json["metadata"] as? [String: Any] {
            #expect(metadata["project"] as? String == "myapp")
            #expect(metadata["fileCount"] as? Int == 1)
        }
        
        if let tasks = json["tasks"] as? [[String: Any]] {
            #expect(tasks.count == 1)
            #expect(tasks[0]["content"] as? String == "Build feature")
            #expect(tasks[0]["priority"] as? String == "high")
        }
        
        if let warnings = json["warnings"] as? [String] {
            #expect(warnings.count == 1)
            #expect(warnings[0] == "Check compatibility")
        }
        
        if let files = json["files"] as? [[String: Any]] {
            #expect(files.count == 1)
            #expect(files[0]["path"] as? String == "script.js")
            #expect(files[0]["language"] as? String == "javascript")
        }
    }
    
    @Test func testMarkdownExport() async throws {
        let promptData = PromptData()
        promptData.tasks = ["Implement login"]
        promptData.warnings = ["Security check required"]
        
        let content = """
        // main.py

        def main():
            pass

        // --- End of main.py ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .markdown,
            promptData: promptData,
            folderURL: URL(fileURLWithPath: "/projects/app")
        )
        
        // Verify Markdown structure
        #expect(exported.contains("# Code Export"))
        #expect(exported.contains("## Metadata"))
        #expect(exported.contains("- **Project**: app"))
        #expect(exported.contains("- **Files**: 1"))
        #expect(exported.contains("## Tasks"))
        #expect(exported.contains("🔴 High: Implement login"))
        #expect(exported.contains("## ⚠️ Warnings"))
        #expect(exported.contains("- Security check required"))
        #expect(exported.contains("## Files"))
        #expect(exported.contains("### main.py"))
        #expect(exported.contains("```python"))
        #expect(exported.contains("def main():"))
    }
    
    @Test func testRawExport() async throws {
        let promptData = PromptData()
        promptData.tasks = ["Fix bug", "Add tests"]
        promptData.warnings = ["Breaking change"]
        
        let content = """
        // file.txt

        content here

        // --- End of file.txt ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .raw,
            promptData: promptData,
            folderURL: nil
        )
        
        // Verify Raw format structure
        #expect(exported.contains("=== TASKS ==="))
        #expect(exported.contains("- Fix bug"))
        #expect(exported.contains("- Add tests"))
        #expect(exported.contains("=== WARNINGS ==="))
        #expect(exported.contains("- Breaking change"))
        #expect(exported.contains("=== CODE ==="))
        #expect(exported.contains("// file.txt"))
        #expect(exported.contains("content here"))
    }
    
    @Test func testEmptyTasksAndWarnings() async throws {
        let promptData = PromptData()
        // Empty tasks and warnings
        
        let content = """
        // test.swift

        let x = 1

        // --- End of test.swift ---

        """
        
        let xmlExport = ExportFormatManager.export(
            content: content,
            format: .xml,
            promptData: promptData,
            folderURL: nil
        )
        
        // Should not contain task or warning sections when empty
        #expect(!xmlExport.contains("<tasks>"))
        #expect(!xmlExport.contains("<warnings>"))
        
        let markdownExport = ExportFormatManager.export(
            content: content,
            format: .markdown,
            promptData: promptData,
            folderURL: nil
        )
        
        #expect(!markdownExport.contains("## Tasks"))
        #expect(!markdownExport.contains("## ⚠️ Warnings"))
    }
    
    @Test func testSpecialCharacterEscaping() async throws {
        let promptData = PromptData()
        promptData.tasks = ["Handle <xml> & \"quotes\""]
        
        let content = """
        // special.xml

        <tag attr="value">Content & more</tag>

        // --- End of special.xml ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .xml,
            promptData: promptData,
            folderURL: nil
        )
        
        // Verify proper XML escaping
        #expect(exported.contains("<![CDATA[Handle <xml> & \"quotes\"]]>"))
        #expect(exported.contains("<![CDATA[<tag attr=\"value\">Content & more</tag>]]>"))
        #expect(!exported.contains("<tag attr=\"value\">")) // Should be inside CDATA
    }
    
    @Test func testMultipleFiles() async throws {
        let promptData = PromptData()
        
        let content = """
        // file1.swift

        struct A {}

        // --- End of file1.swift ---

        // file2.js

        const b = 1;

        // --- End of file2.js ---

        // file3.py

        def c():
            pass

        // --- End of file3.py ---

        """
        
        let exported = ExportFormatManager.export(
            content: content,
            format: .xml,
            promptData: promptData,
            folderURL: nil
        )
        
        // Verify all files are included
        #expect(exported.contains("<fileCount>3</fileCount>"))
        #expect(exported.contains("<path>file1.swift</path>"))
        #expect(exported.contains("<path>file2.js</path>"))
        #expect(exported.contains("<path>file3.py</path>"))
        #expect(exported.contains("<language>swift</language>"))
        #expect(exported.contains("<language>javascript</language>"))
        #expect(exported.contains("<language>python</language>"))
    }
}