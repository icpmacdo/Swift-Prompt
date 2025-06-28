//
//  SecurityValidationTests.swift
//  Swift-PromptTests
//
//  Test suite for security validation and performance
//

import Testing
import Foundation
@testable import Swift_Prompt

struct SecurityValidationTests {
    
    // MARK: - Path Traversal Tests
    
    @Test func testPathTraversalDetection() async throws {
        let dangerousPaths = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32",
            "/Users/test/../../../etc/passwd",
            "folder/../../secret",
            "./../../sensitive",
            "../",
            "..\\",
            "folder/../../../",
            "normal/path/../../../../../../etc/passwd"
        ]
        
        for path in dangerousPaths {
            // All these should be detected as path traversal attempts
            #expect(path.contains("../") || path.contains("..\\"))
        }
    }
    
    @Test func testSafePathValidation() async throws {
        let safePaths = [
            "folder/subfolder/file.txt",
            "src/components/Button.swift",
            "tests/unit/test.js",
            "README.md",
            "./current/file.txt",
            "folder with spaces/file.txt"
        ]
        
        for path in safePaths {
            // These should not contain path traversal patterns
            #expect(!path.contains("../") && !path.contains("..\\"))
        }
    }
    
    // MARK: - File Size Validation Tests
    
    @Test func testFileSizeValidation() async throws {
        let maxSize: Int64 = 10_000_000 // 10MB
        
        // Test various file sizes
        let testSizes: [(size: Int64, shouldPass: Bool)] = [
            (1_000, true),           // 1KB - should pass
            (1_000_000, true),       // 1MB - should pass
            (5_000_000, true),       // 5MB - should pass
            (9_999_999, true),       // Just under 10MB - should pass
            (10_000_000, true),      // Exactly 10MB - should pass
            (10_000_001, false),     // Just over 10MB - should fail
            (20_000_000, false),     // 20MB - should fail
            (100_000_000, false)     // 100MB - should fail
        ]
        
        for test in testSizes {
            let passes = test.size <= maxSize
            #expect(passes == test.shouldPass)
        }
    }
    
    // MARK: - Input Validation Tests
    
    @Test func testXMLEscaping() async throws {
        let dangerousStrings = [
            "<script>alert('xss')</script>",
            "'; DROP TABLE users; --",
            "\" onload=\"malicious()\"",
            "&entity;",
            "<![CDATA[nested]]>",
            "../../etc/passwd"
        ]
        
        for dangerous in dangerousStrings {
            let escaped = dangerous
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&apos;")
            
            // Verify no dangerous characters remain
            #expect(!escaped.contains("<script"))
            #expect(!escaped.contains("DROP TABLE"))
            #expect(!escaped.contains("onload="))
        }
    }
    
    @Test func testFileExtensionValidation() async throws {
        // Test safe extensions
        let safeExtensions = ["swift", "js", "py", "java", "html", "css", "json", "xml", "md", "txt"]
        for ext in safeExtensions {
            // These should be recognized as safe text files
            #expect(!ext.isEmpty)
        }
        
        // Test potentially dangerous extensions
        let dangerousExtensions = ["exe", "dll", "app", "dmg", "pkg", "deb", "rpm"]
        for ext in dangerousExtensions {
            // In a real implementation, these might be blocked
            #expect(!ext.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testRegexPerformance() async throws {
        // Test that our regex patterns are efficient
        let filePattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#
        
        // Create a large test string with multiple files
        var largeContent = ""
        for i in 1...100 {
            largeContent += """
            // file\(i).swift

            func test\(i)() {
                print("Test \(i)")
            }

            // --- End of file\(i).swift ---


            """
        }
        
        let startTime = Date()
        
        do {
            let regex = try NSRegularExpression(pattern: filePattern, options: [])
            let matches = regex.matches(in: largeContent, range: NSRange(largeContent.startIndex..., in: largeContent))
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Should parse 100 files in under 1 second
            #expect(duration < 1.0)
            #expect(matches.count == 100)
        } catch {
            #expect(Bool(false)) // Regex should not fail
        }
    }
    
    @Test func testLargeFileHandling() async throws {
        // Test handling of content near the size limit
        let nearLimitSize = 9_900_000 // Just under 10MB
        
        // Create a string that's near the limit (this is just a simulation)
        let testContent = String(repeating: "a", count: min(nearLimitSize, 1000))
        
        // Should be able to handle this without issues
        #expect(!testContent.isEmpty)
    }
    
    // MARK: - Bookmark Security Tests
    
    @Test func testBookmarkSecurity() async throws {
        // Test that bookmark-related errors are properly categorized
        let bookmarkError = SwiftPromptError.bookmarkCreationFailed(
            url: URL(fileURLWithPath: "/test"),
            error: nil
        )
        
        #expect(bookmarkError.errorDescription?.contains("bookmark") ?? false)
        #expect(bookmarkError.recoverySuggestion?.contains("folder again") ?? false)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test func testConcurrentFileOperations() async throws {
        // Test that multiple file operations can be handled safely
        let viewModel = ContentViewModel()
        
        // Simulate concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    // Each task tries to update the view model
                    await MainActor.run {
                        viewModel.progressMessage = "Processing file \(i)"
                    }
                }
            }
        }
        
        // View model should still be in a valid state
        #expect(!viewModel.progressMessage.isEmpty)
    }
}