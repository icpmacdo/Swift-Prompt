//
//  Swift-PromptTests.swift
//  Swift-PromptTests
//
//  Created by Ian MacDonald on 2024-09-21.
//

import Testing
@testable import Swift_Prompt
import Foundation // Required for Set algebra

struct SwiftPromptTests {

    @Test func exampleTest() async throws {
        #expect(true)
    }

    @Test func testCommonExtensionsPresent_InitialSelectionEmpty() throws {
        let viewModel = ContentViewModel()
        viewModel.availableFileTypes = ["swift", "js", "txt"]
        viewModel.selectedFileTypes = [] // Ensure it's empty

        // Logic snippet from updateAvailableFileTypes
        let found = Set(viewModel.availableFileTypes)
        if viewModel.selectedFileTypes.isEmpty {
            let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
            if !preferredSelection.isEmpty {
                viewModel.selectedFileTypes = preferredSelection
            } else {
                viewModel.selectedFileTypes = found
            }
        }
        
        #expect(viewModel.selectedFileTypes == Set(["swift", "js"]))
    }
    
    @Test func testOnlyNonCommonExtensionsPresent_InitialSelectionEmpty() throws {
        let viewModel = ContentViewModel()
        viewModel.availableFileTypes = ["log", "dat"]
        viewModel.selectedFileTypes = []

        let found = Set(viewModel.availableFileTypes)
        if viewModel.selectedFileTypes.isEmpty {
            let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
            if !preferredSelection.isEmpty {
                viewModel.selectedFileTypes = preferredSelection
            } else {
                viewModel.selectedFileTypes = found
            }
        }
        
        #expect(viewModel.selectedFileTypes == Set(["log", "dat"]))
    }
    
    @Test func testInitialSelectionNotEmpty() throws {
        let viewModel = ContentViewModel()
        viewModel.availableFileTypes = ["swift", "js", "txt"]
        viewModel.selectedFileTypes = ["txt"]

        let found = Set(viewModel.availableFileTypes)
        if viewModel.selectedFileTypes.isEmpty { // This block should be skipped
            let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
            if !preferredSelection.isEmpty {
                viewModel.selectedFileTypes = preferredSelection
            } else {
                viewModel.selectedFileTypes = found
            }
        }
        
        #expect(viewModel.selectedFileTypes == Set(["txt"]))
    }
    
    @Test func testNoFilesFound_InitialSelectionEmpty() throws {
        let viewModel = ContentViewModel()
        viewModel.availableFileTypes = []
        viewModel.selectedFileTypes = []

        let found = Set(viewModel.availableFileTypes)
        if viewModel.selectedFileTypes.isEmpty {
            let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
            if !preferredSelection.isEmpty {
                viewModel.selectedFileTypes = preferredSelection
            } else {
                viewModel.selectedFileTypes = found
            }
        }
        
        #expect(viewModel.selectedFileTypes.isEmpty)
    }
    
    @Test func testCommonExtensionNotPresentInAvailable() throws {
        let viewModel = ContentViewModel()
        viewModel.availableFileTypes = ["swift", "txt"] // "js" is common but not in availableFileTypes
        viewModel.selectedFileTypes = []

        let found = Set(viewModel.availableFileTypes)
        if viewModel.selectedFileTypes.isEmpty {
            let preferredSelection = found.intersection(ContentViewModel.commonCodeFileExtensions)
            if !preferredSelection.isEmpty {
                viewModel.selectedFileTypes = preferredSelection
            } else {
                viewModel.selectedFileTypes = found
            }
        }
        
        #expect(viewModel.selectedFileTypes == Set(["swift"]))
    }
}
