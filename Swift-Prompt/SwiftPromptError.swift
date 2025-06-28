//
//  SwiftPromptError.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-06-28.
//

import Foundation

enum SwiftPromptError: LocalizedError {
    // File System Errors
    case fileAccessDenied(path: String)
    case fileNotFound(path: String)
    case fileReadError(path: String, underlying: Error)
    case fileWriteError(path: String, underlying: Error)
    case directoryNotFound(path: String)
    case failedToCreateDirectory(path: String, underlying: Error?)
    case invalidFileFormat(path: String)
    case fileTooLarge(path: String, size: Int)
    case unsupportedFileType(path: String, extension: String)
    
    // Security Errors
    case securityScopedResourceError
    case pathTraversalAttempt(path: String)
    case bookmarkCreationFailed(url: URL, error: Error?)
    case bookmarkResolutionFailed(error: Error?)
    
    // Parsing Errors
    case xmlGenerationFailed(reason: String)
    case responseParsingFailed(reason: String)
    case jsonParsingFailed(reason: String)
    case regexPatternInvalid(pattern: String, error: Error?)
    case noCodeBlocksFound
    
    // State Errors
    case folderSelectionCancelled
    case noFolderSelected
    case noFilesFound
    case operationInProgress
    case operationCancelled
    
    // Export/Import Errors
    case backupFailed(reason: String)
    case exportFailed(format: String, reason: String)
    case importFailed(reason: String)
    case clipboardOperationFailed
    
    // Validation Errors
    case invalidInput(field: String, reason: String)
    case emptyContent
    case invalidXMLStructure(details: String)
    
    var errorDescription: String? {
        switch self {
        // File System Errors
        case .fileAccessDenied(let path):
            return "Access denied to file: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileReadError(let path, let error):
            return "Failed to read \(path): \(error.localizedDescription)"
        case .fileWriteError(let path, let error):
            return "Failed to write \(path): \(error.localizedDescription)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .failedToCreateDirectory(let path, let error):
            return "Failed to create directory at \(path): \(error?.localizedDescription ?? "Unknown error")"
        case .invalidFileFormat(let path):
            return "Invalid file format: \(path)"
        case .fileTooLarge(let path, let size):
            let sizeInMB = Double(size) / 1_048_576
            return "File too large: \(path) (\(String(format: "%.1f", sizeInMB)) MB)"
        case .unsupportedFileType(let path, let ext):
            return "Unsupported file type '\(ext)' for file: \(path)"
            
        // Security Errors
        case .securityScopedResourceError:
            return "Failed to access security-scoped resource"
        case .pathTraversalAttempt(let path):
            return "Security error: Path traversal attempt detected in: \(path)"
        case .bookmarkCreationFailed(let url, let error):
            return "Failed to create bookmark for \(url.path): \(error?.localizedDescription ?? "Unknown error")"
        case .bookmarkResolutionFailed(let error):
            return "Failed to resolve bookmark: \(error?.localizedDescription ?? "Unknown error")"
            
        // Parsing Errors
        case .xmlGenerationFailed(let reason):
            return "XML generation failed: \(reason)"
        case .responseParsingFailed(let reason):
            return "Failed to parse AI response: \(reason)"
        case .jsonParsingFailed(let reason):
            return "JSON parsing failed: \(reason)"
        case .regexPatternInvalid(let pattern, let error):
            return "Invalid regex pattern '\(pattern)': \(error?.localizedDescription ?? "Unknown error")"
        case .noCodeBlocksFound:
            return "No code blocks found in the response"
            
        // State Errors
        case .folderSelectionCancelled:
            return "Folder selection was cancelled"
        case .noFolderSelected:
            return "No folder selected. Please select a folder first"
        case .noFilesFound:
            return "No files found matching the selected criteria"
        case .operationInProgress:
            return "Another operation is already in progress"
        case .operationCancelled:
            return "Operation was cancelled"
            
        // Export/Import Errors
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        case .exportFailed(let format, let reason):
            return "Failed to export in \(format) format: \(reason)"
        case .importFailed(let reason):
            return "Failed to import: \(reason)"
        case .clipboardOperationFailed:
            return "Failed to access clipboard"
            
        // Validation Errors
        case .invalidInput(let field, let reason):
            return "Invalid input for \(field): \(reason)"
        case .emptyContent:
            return "Content is empty"
        case .invalidXMLStructure(let details):
            return "Invalid XML structure: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        // File System Errors
        case .fileAccessDenied:
            return "Check file permissions and try again"
        case .fileNotFound:
            return "Verify the file exists and the path is correct"
        case .fileReadError, .fileWriteError:
            return "Check disk space and file permissions"
        case .directoryNotFound:
            return "Ensure the directory exists or create it first"
        case .failedToCreateDirectory:
            return "Check disk space and permissions"
        case .invalidFileFormat:
            return "Only text-based files are supported"
        case .fileTooLarge:
            return "Try excluding large files or increase the size limit in preferences"
        case .unsupportedFileType:
            return "Add this file type to the supported extensions in settings"
            
        // Security Errors
        case .securityScopedResourceError:
            return "Re-select the folder to restore access"
        case .pathTraversalAttempt:
            return "Use only relative paths within the selected folder"
        case .bookmarkCreationFailed, .bookmarkResolutionFailed:
            return "Try selecting the folder again"
            
        // Parsing Errors
        case .xmlGenerationFailed:
            return "Try selecting fewer files or check for special characters"
        case .responseParsingFailed:
            return "Ensure the AI response contains properly formatted code blocks"
        case .jsonParsingFailed:
            return "Check the JSON format and try again"
        case .regexPatternInvalid:
            return "Fix the regex pattern syntax"
        case .noCodeBlocksFound:
            return "Ensure the response contains properly formatted code blocks with ```"
            
        // State Errors
        case .folderSelectionCancelled:
            return "Select a folder to continue"
        case .noFolderSelected:
            return "Click 'Select Folder' to choose a project folder"
        case .noFilesFound:
            return "Check your file type filters and folder contents"
        case .operationInProgress:
            return "Wait for the current operation to complete"
        case .operationCancelled:
            return "Restart the operation if needed"
            
        // Export/Import Errors
        case .backupFailed:
            return "Check disk space and permissions for the backup directory"
        case .exportFailed:
            return "Check the export format and try again"
        case .importFailed:
            return "Verify the import file format is correct"
        case .clipboardOperationFailed:
            return "Grant clipboard access permissions"
            
        // Validation Errors
        case .invalidInput:
            return "Correct the input and try again"
        case .emptyContent:
            return "Add some content before proceeding"
        case .invalidXMLStructure:
            return "Fix the XML structure and try again"
        }
    }
}

// MARK: - Error Severity
extension SwiftPromptError {
    enum Severity {
        case info
        case warning
        case error
        case critical
    }
    
    var severity: Severity {
        switch self {
        case .operationCancelled, .noFilesFound, .noCodeBlocksFound, .emptyContent:
            return .info
        case .unsupportedFileType, .invalidInput, .folderSelectionCancelled:
            return .warning
        case .pathTraversalAttempt, .securityScopedResourceError:
            return .critical
        default:
            return .error
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .operationCancelled, .operationInProgress, .noFolderSelected, .noFilesFound,
             .noCodeBlocksFound, .emptyContent, .invalidInput, .folderSelectionCancelled:
            return true
        case .pathTraversalAttempt:
            return false
        default:
            return true
        }
    }
}

// MARK: - Error Conversion Helper
extension SwiftPromptError {
    static func from(_ error: Error, context: String? = nil) -> SwiftPromptError {
        if let swiftError = error as? SwiftPromptError {
            return swiftError
        }
        
        let nsError = error as NSError
        
        // Check for common Foundation/Cocoa errors
        switch (nsError.domain, nsError.code) {
        case (NSCocoaErrorDomain, NSFileNoSuchFileError):
            let path = nsError.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileNotFound(path: path)
        case (NSCocoaErrorDomain, NSFileWriteNoPermissionError):
            let path = nsError.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileAccessDenied(path: path)
        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError):
            let path = nsError.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
            return .fileWriteError(path: path, underlying: error)
        default:
            // Generic fallback based on context
            if let ctx = context {
                return .importFailed(reason: "\(ctx): \(error.localizedDescription)")
            }
            return .importFailed(reason: error.localizedDescription)
        }
    }
}