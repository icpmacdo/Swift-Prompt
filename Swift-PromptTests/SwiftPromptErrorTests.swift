//
//  SwiftPromptErrorTests.swift
//  Swift-PromptTests
//
//  Test suite for error handling framework
//

import Testing
import Foundation
@testable import Swift_Prompt

struct SwiftPromptErrorTests {
    
    // MARK: - Error Description Tests
    
    @Test func testFileSystemErrorDescriptions() async throws {
        let fileNotFound = SwiftPromptError.fileNotFound(path: "/test/file.txt")
        #expect(fileNotFound.errorDescription == "File not found: /test/file.txt")
        #expect(fileNotFound.recoverySuggestion == "Verify the file exists and the path is correct")
        
        let accessDenied = SwiftPromptError.fileAccessDenied(path: "/secure/file.txt")
        #expect(accessDenied.errorDescription == "Access denied to file: /secure/file.txt")
        #expect(accessDenied.recoverySuggestion == "Check file permissions and try again")
        
        let fileTooLarge = SwiftPromptError.fileTooLarge(path: "/big.txt", size: 15_000_000)
        #expect(fileTooLarge.errorDescription?.contains("14.3 MB") ?? false)
        #expect(fileTooLarge.recoverySuggestion == "Try excluding large files or increase the size limit in preferences")
    }
    
    @Test func testSecurityErrorDescriptions() async throws {
        let pathTraversal = SwiftPromptError.pathTraversalAttempt(path: "../../etc/passwd")
        #expect(pathTraversal.errorDescription == "Security error: Path traversal attempt detected in: ../../etc/passwd")
        #expect(pathTraversal.recoverySuggestion == "Use only relative paths within the selected folder")
        #expect(pathTraversal.severity == .critical)
        #expect(!pathTraversal.isRecoverable)
    }
    
    @Test func testParsingErrorDescriptions() async throws {
        let xmlError = SwiftPromptError.xmlGenerationFailed(reason: "Invalid characters")
        #expect(xmlError.errorDescription == "XML generation failed: Invalid characters")
        
        let noCodeBlocks = SwiftPromptError.noCodeBlocksFound
        #expect(noCodeBlocks.errorDescription == "No code blocks found in the response")
        #expect(noCodeBlocks.recoverySuggestion == "Ensure the response contains properly formatted code blocks with ```")
        #expect(noCodeBlocks.severity == .info)
    }
    
    @Test func testStateErrorDescriptions() async throws {
        let noFolder = SwiftPromptError.noFolderSelected
        #expect(noFolder.errorDescription == "No folder selected. Please select a folder first")
        #expect(noFolder.recoverySuggestion == "Click 'Select Folder' to choose a project folder")
        #expect(noFolder.isRecoverable)
        
        let operationCancelled = SwiftPromptError.operationCancelled
        #expect(operationCancelled.severity == .info)
        #expect(operationCancelled.isRecoverable)
    }
    
    // MARK: - Error Severity Tests
    
    @Test func testErrorSeverityLevels() async throws {
        // Info level
        #expect(SwiftPromptError.operationCancelled.severity == .info)
        #expect(SwiftPromptError.noFilesFound.severity == .info)
        #expect(SwiftPromptError.emptyContent.severity == .info)
        
        // Warning level
        #expect(SwiftPromptError.unsupportedFileType(path: "test.exe", extension: "exe").severity == .warning)
        #expect(SwiftPromptError.folderSelectionCancelled.severity == .warning)
        
        // Critical level
        #expect(SwiftPromptError.pathTraversalAttempt(path: "../").severity == .critical)
        #expect(SwiftPromptError.securityScopedResourceError.severity == .critical)
        
        // Error level (default)
        #expect(SwiftPromptError.fileNotFound(path: "test").severity == .error)
        #expect(SwiftPromptError.xmlGenerationFailed(reason: "test").severity == .error)
    }
    
    // MARK: - Error Recoverability Tests
    
    @Test func testErrorRecoverability() async throws {
        // Recoverable errors
        #expect(SwiftPromptError.operationCancelled.isRecoverable)
        #expect(SwiftPromptError.noFolderSelected.isRecoverable)
        #expect(SwiftPromptError.emptyContent.isRecoverable)
        #expect(SwiftPromptError.invalidInput(field: "test", reason: "invalid").isRecoverable)
        
        // Non-recoverable errors
        #expect(!SwiftPromptError.pathTraversalAttempt(path: "test").isRecoverable)
        
        // Default recoverable
        #expect(SwiftPromptError.fileNotFound(path: "test").isRecoverable)
        #expect(SwiftPromptError.xmlGenerationFailed(reason: "test").isRecoverable)
    }
    
    // MARK: - Error Conversion Tests
    
    @Test func testErrorConversion() async throws {
        // Test NSError to SwiftPromptError conversion
        let nsError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileNoSuchFileError,
            userInfo: [NSFilePathErrorKey: "/test/missing.txt"]
        )
        
        let converted = SwiftPromptError.from(nsError)
        
        if case .fileNotFound(let path) = converted {
            #expect(path == "/test/missing.txt")
        } else {
            #expect(Bool(false)) // Should be fileNotFound
        }
    }
    
    @Test func testPermissionErrorConversion() async throws {
        let nsError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteNoPermissionError,
            userInfo: [NSFilePathErrorKey: "/protected/file.txt"]
        )
        
        let converted = SwiftPromptError.from(nsError)
        
        if case .fileAccessDenied(let path) = converted {
            #expect(path == "/protected/file.txt")
        } else {
            #expect(Bool(false)) // Should be fileAccessDenied
        }
    }
    
    @Test func testGenericErrorConversion() async throws {
        let genericError = NSError(
            domain: "CustomDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
        )
        
        let converted = SwiftPromptError.from(genericError, context: "Testing")
        
        if case .importFailed(let reason) = converted {
            #expect(reason.contains("Testing"))
            #expect(reason.contains("Something went wrong"))
        } else {
            #expect(Bool(false)) // Should be importFailed
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test func testErrorHandlingInFileOperations() async throws {
        // Test that proper errors are thrown for invalid paths
        let viewModel = ContentViewModel()
        viewModel.folderURL = URL(fileURLWithPath: "/test/project")
        
        // Test path traversal detection
        do {
            _ = try viewModel.readFileContent(at: URL(fileURLWithPath: "/test/project/../../../etc/passwd"))
            #expect(Bool(false)) // Should throw
        } catch let error as SwiftPromptError {
            if case .pathTraversalAttempt = error {
                #expect(true)
            } else {
                #expect(Bool(false)) // Should be path traversal error
            }
        }
    }
    
    @Test func testErrorRecoverySuggestions() async throws {
        // Test that all errors have meaningful recovery suggestions
        let testErrors: [SwiftPromptError] = [
            .fileNotFound(path: "test"),
            .fileAccessDenied(path: "test"),
            .directoryNotFound(path: "test"),
            .failedToCreateDirectory(path: "test", underlying: nil),
            .xmlGenerationFailed(reason: "test"),
            .noCodeBlocksFound,
            .noFolderSelected,
            .pathTraversalAttempt(path: "test"),
            .emptyContent
        ]
        
        for error in testErrors {
            let suggestion = error.recoverySuggestion
            #expect(suggestion != nil)
            #expect(!(suggestion?.isEmpty ?? true))
        }
    }
}