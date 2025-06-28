//
//  ContentViewModelTests.swift
//  Swift-PromptTests
//
//  Test suite for ContentViewModel functionality
//

import Testing
import SwiftUI
import Combine
@testable import Swift_Prompt

@MainActor
struct ContentViewModelTests {
    
    // MARK: - Initialization Tests
    
    @Test func testViewModelInitialization() async throws {
        let viewModel = ContentViewModel()
        
        #expect(!viewModel.isProcessing)
        #expect(viewModel.progressMessage.isEmpty)
        #expect(viewModel.textAreaContents.isEmpty)
        #expect(viewModel.folderURL == nil)
        #expect(!viewModel.showingError)
        #expect(viewModel.selectedExportFormat == .xml)
        #expect(viewModel.availableFileTypes.isEmpty)
        #expect(viewModel.selectedFileTypes.isEmpty)
    }
    
    // MARK: - File Type Management Tests
    
    @Test func testFileTypeLoading() async throws {
        let viewModel = ContentViewModel()
        
        // Load saved file types
        viewModel.loadSelectedFileTypes()
        
        // By default, should be empty or have default values
        #expect(viewModel.selectedFileTypes.isEmpty || viewModel.selectedFileTypes.contains("*"))
    }
    
    @Test func testFileTypeSaving() async throws {
        let viewModel = ContentViewModel()
        
        // Set some file types
        viewModel.selectedFileTypes = ["swift", "js", "py"]
        
        // Save them
        viewModel.saveSelectedFileTypes()
        
        // Create new view model and load
        let newViewModel = ContentViewModel()
        newViewModel.loadSelectedFileTypes()
        
        // Should have the saved types
        #expect(newViewModel.selectedFileTypes.contains("swift"))
        #expect(newViewModel.selectedFileTypes.contains("js"))
        #expect(newViewModel.selectedFileTypes.contains("py"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testErrorHandling() async throws {
        let viewModel = ContentViewModel()
        
        let testError = SwiftPromptError.fileNotFound(path: "/test/file.txt")
        viewModel.handleError(testError)
        
        #expect(viewModel.showingError)
        #expect(viewModel.currentError != nil)
        
        if case .fileNotFound(let path) = viewModel.currentError {
            #expect(path == "/test/file.txt")
        } else {
            #expect(Bool(false))
        }
    }
    
    // MARK: - Clear All Tests
    
    @Test func testClearAll() async throws {
        let viewModel = ContentViewModel()
        
        // Set some values
        viewModel.isProcessing = true
        viewModel.progressMessage = "Processing..."
        viewModel.textAreaContents = "Some content"
        viewModel.folderURL = URL(fileURLWithPath: "/test")
        viewModel.successMessage = "Success!"
        viewModel.showSuccessBanner = true
        
        // Clear all
        viewModel.clearAll()
        
        // Everything should be reset
        #expect(!viewModel.isProcessing)
        #expect(viewModel.progressMessage.isEmpty)
        #expect(viewModel.textAreaContents.isEmpty)
        #expect(viewModel.folderURL == nil)
        #expect(viewModel.successMessage.isEmpty)
        #expect(!viewModel.showSuccessBanner)
    }
    
    // MARK: - File Reading Tests
    
    @Test func testFileReadingSecurity() async throws {
        let viewModel = ContentViewModel()
        viewModel.folderURL = URL(fileURLWithPath: "/Users/test/project")
        
        // Test path traversal attempt
        do {
            _ = try viewModel.readFileContent(at: URL(fileURLWithPath: "/Users/test/project/../../../etc/passwd"))
            #expect(Bool(false)) // Should throw
        } catch SwiftPromptError.pathTraversalAttempt {
            #expect(true) // Expected error
        } catch {
            #expect(Bool(false)) // Wrong error type
        }
        
        // Test file outside folder
        do {
            _ = try viewModel.readFileContent(at: URL(fileURLWithPath: "/Users/other/file.txt"))
            #expect(Bool(false)) // Should throw
        } catch SwiftPromptError.pathTraversalAttempt {
            #expect(true) // Expected error
        } catch {
            #expect(Bool(false)) // Wrong error type
        }
    }
    
    @Test func testFileSizeLimit() async throws {
        let viewModel = ContentViewModel()
        viewModel.folderURL = URL(fileURLWithPath: "/test")
        
        // Create a mock file that's too large (we can't actually test this without file system access)
        // This test would need to be integration tested with actual files
        
        // For now, test that the size limit is reasonable
        #expect(viewModel.maxFileSize == 10_000_000) // 10MB
    }
    
    // MARK: - Export Format Tests
    
    @Test func testExportFormatSelection() async throws {
        let viewModel = ContentViewModel()
        
        // Default should be XML
        #expect(viewModel.selectedExportFormat == .xml)
        
        // Test changing format
        viewModel.selectedExportFormat = .json
        #expect(viewModel.selectedExportFormat == .json)
        
        viewModel.selectedExportFormat = .markdown
        #expect(viewModel.selectedExportFormat == .markdown)
        
        viewModel.selectedExportFormat = .raw
        #expect(viewModel.selectedExportFormat == .raw)
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test func testProgressTracking() async throws {
        let viewModel = ContentViewModel()
        
        // Initial state
        #expect(viewModel.filesCopied == 0)
        #expect(viewModel.totalFiles == 0)
        #expect(viewModel.filesProcessed == 0)
        
        // These would be set during file processing
        // We can't test the actual file processing without file system access
        // but we can verify the properties exist and are accessible
    }
    
    // MARK: - File Tree Tests
    
    @Test func testFileTreeNodeCreation() async throws {
        // Test FileTreeNode creation
        let rootNode = FileTreeNode(name: "root", path: "/root", isDirectory: true)
        #expect(rootNode.name == "root")
        #expect(rootNode.path == "/root")
        #expect(rootNode.isDirectory)
        #expect(rootNode.children.isEmpty)
        #expect(rootNode.isExpanded)
        
        // Test adding children
        let childNode = FileTreeNode(name: "child.txt", path: "/root/child.txt", isDirectory: false)
        rootNode.children.append(childNode)
        
        #expect(rootNode.children.count == 1)
        #expect(rootNode.children[0].name == "child.txt")
        #expect(!rootNode.children[0].isDirectory)
    }
    
    // MARK: - State Management Tests
    
    @Test func testStateFlags() async throws {
        let viewModel = ContentViewModel()
        
        // Test processing state
        viewModel.isProcessing = true
        #expect(viewModel.isProcessing)
        
        viewModel.isProcessing = false
        #expect(!viewModel.isProcessing)
        
        // Test error state
        viewModel.showingError = true
        #expect(viewModel.showingError)
        
        viewModel.showingError = false
        #expect(!viewModel.showingError)
        
        // Test success banner
        viewModel.showSuccessBanner = true
        #expect(viewModel.showSuccessBanner)
        
        viewModel.showSuccessBanner = false
        #expect(!viewModel.showSuccessBanner)
    }
}