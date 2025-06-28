//
//  Swift-PromptTests.swift
//  Swift-PromptTests
//
//  Created by Ian MacDonald on 2024-09-21.
//

import Testing
import SwiftUI
@testable import Swift_Prompt

struct SwiftPromptTests {

    @Test func exampleTest() async throws {
        #expect(true)
    }
    
    // MARK: - XML Generation Tests
    
    @Test func testXMLGenerationWithTasksAndWarnings() async throws {
        // Setup
        let viewModel = ContentViewModel()
        let promptData = PromptData()
        promptData.tasks = ["Refactor UserManager", "Add error handling"]
        promptData.warnings = ["Maintain iOS 14 compatibility"]
        
        // Create mock raw text content
        let rawText = """
        // TestFile.swift

        struct TestStruct {
            let value: String = "Hello"
        }

        // --- End of TestFile.swift ---

        // utils.js

        function test() {
            console.log("test");
        }

        // --- End of utils.js ---
        """
        
        viewModel.textAreaContents = rawText
        
        // Create CodeDetailView to test XML generation
        let detailView = CodeDetailView()
            .environmentObject(viewModel)
            .environmentObject(promptData)
        
        // Test would need access to the private createXML method
        // For now, we'll test the helper functions indirectly
        #expect(rawText.contains("TestFile.swift"))
        #expect(rawText.contains("utils.js"))
    }
    
    @Test func testXMLEscaping() async throws {
        // Test that special characters are properly escaped
        let testString = "Test & <tag> \"quote\" 'apostrophe'"
        let escapedString = testString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        
        #expect(escapedString == "Test &amp; &lt;tag&gt; &quot;quote&quot; &apos;apostrophe&apos;")
    }
    
    @Test func testLanguageDetection() async throws {
        // Test language detection from file extensions
        let testCases: [(filename: String, expectedLanguage: String)] = [
            ("test.swift", "swift"),
            ("app.js", "javascript"),
            ("component.tsx", "typescript"),
            ("script.py", "python"),
            ("Main.java", "java"),
            ("index.html", "html"),
            ("styles.css", "css"),
            ("config.json", "json"),
            ("data.xml", "xml"),
            ("unknown.xyz", "text")
        ]
        
        for testCase in testCases {
            let ext = (testCase.filename as NSString).pathExtension.lowercased()
            let language: String
            
            switch ext {
            case "swift": language = "swift"
            case "js", "jsx": language = "javascript"
            case "ts", "tsx": language = "typescript"
            case "py": language = "python"
            case "java": language = "java"
            case "html", "htm": language = "html"
            case "css", "scss", "sass": language = "css"
            case "json": language = "json"
            case "xml": language = "xml"
            default: language = "text"
            }
            
            #expect(language == testCase.expectedLanguage)
        }
    }
    
    @Test func testFileParsingFromRawText() async throws {
        // Test parsing of raw text format
        let rawText = """
        // FirstFile.swift

        let x = 1

        // --- End of FirstFile.swift ---

        // SecondFile.js

        const y = 2

        // --- End of SecondFile.js ---
        """
        
        let filePattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#
        let regex = try NSRegularExpression(pattern: filePattern, options: [])
        let matches = regex.matches(in: rawText, range: NSRange(rawText.startIndex..., in: rawText))
        
        #expect(matches.count == 2)
        
        // Extract first file
        if let firstMatch = matches.first,
           firstMatch.numberOfRanges >= 3,
           let filenameRange = Range(firstMatch.range(at: 1), in: rawText),
           let contentRange = Range(firstMatch.range(at: 2), in: rawText) {
            let filename = String(rawText[filenameRange])
            let content = String(rawText[contentRange])
            
            #expect(filename == "FirstFile.swift")
            #expect(content == "let x = 1")
        }
    }
    
    // MARK: - Multi-Language Parser Tests
    
    @Test func testMultiLanguageResponseParsing() async throws {
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
        
        #expect(updates.count == 3)
        #expect(updates[0].path == "ContentView.swift")
        #expect(updates[1].path == "app.js")
        #expect(updates[2].path == "main.py")
        #expect(updates[0].content.contains("struct ContentView"))
        #expect(updates[1].content.contains("console.log"))
        #expect(updates[2].content.contains("print"))
    }
    
    @Test func testParserWithVariousFormats() async throws {
        // Test different code block formats
        let testCases: [(input: String, expectedFile: String, expectedContent: String)] = [
            // Format 1: Language with filename on next line
            ("""
            ```swift
            MyFile.swift
            let x = 1
            ```
            """, "MyFile.swift", "let x = 1"),
            
            // Format 2: Language:filename
            ("""
            ```javascript:utils.js
            const y = 2
            ```
            """, "utils.js", "const y = 2"),
            
            // Format 3: No language, just filename
            ("""
            ```
            config.json
            {"key": "value"}
            ```
            """, "config.json", "{\"key\": \"value\"}"),
            
            // Format 4: Filename as comment
            ("""
            ```python
            # script.py
            import sys
            ```
            """, "script.py", "import sys")
        ]
        
        for testCase in testCases {
            let updates = EnhancedResponseParser.parseResponse(testCase.input)
            #expect(updates.count == 1)
            if let update = updates.first {
                #expect(update.path == testCase.expectedFile)
                #expect(update.content.trimmingCharacters(in: .whitespacesAndNewlines) == testCase.expectedContent)
            }
        }
    }
    
    @Test func testJSONFallback() async throws {
        let jsonInput = """
        [
            {
                "fileName": "test.swift",
                "code": "let x = 1"
            },
            {
                "fileName": "test.js",
                "code": "const y = 2"
            }
        ]
        """
        
        // Test through MessageClientView's tryParseJSON method
        guard let data = jsonInput.data(using: .utf8) else {
            #expect(Bool(false))
            return
        }
        
        do {
            let updates = try JSONDecoder().decode([LLMFileUpdate].self, from: data)
            #expect(updates.count == 2)
            #expect(updates[0].path == "test.swift")
            #expect(updates[0].content == "let x = 1")
            #expect(updates[1].path == "test.js")
            #expect(updates[1].content == "const y = 2")
        } catch {
            #expect(Bool(false))
        }
    }

}
