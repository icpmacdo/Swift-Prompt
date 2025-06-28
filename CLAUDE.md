# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Swift-Prompt Development Guide

## Build/Test Commands
- Build: Open project in Xcode and use ⌘+B
- Run: Use ⌘+R in Xcode
- Test: Use ⌘+U to run all tests
- Run single test: Click the diamond icon next to a test function in Xcode

## Code Style Guidelines
- **Imports**: Group Foundation/SwiftUI imports first, followed by app modules
- **Formatting**: 4-space indentation, 100 character line limit
- **Naming**: Use camelCase for variables/functions, PascalCase for types
- **Documentation**: Add comments above complex functions, use /// for documentation
- **Error Handling**: Use try/catch with descriptive error messages, log with SwiftLog()
- **SwiftUI**: Use @ViewBuilder for complex view composition, extract subviews to extensions
- **Color Theme**: Use predefined theme colors (softBeigeSecondary, etc.) for consistency

## High-Level Architecture

Swift-Prompt is a macOS SwiftUI app that aggregates code files for AI prompts. It follows MVVM architecture with two main state objects:

1. **ContentViewModel** (@MainActor): Central state management
   - Handles folder selection via NSOpenPanel with security-scoped bookmarks
   - Monitors file changes using FileMonitor (DispatchSource-based)
   - Manages file type filtering (persisted in UserDefaults)
   - Excludes standard directories: .git, node_modules, dist, build

2. **PromptData**: Stores tasks/warnings for AI prompts using XML formatting

### Key User Flow
1. User selects folder → ContentViewModel creates security bookmark
2. FileMonitor watches for changes → triggers re-aggregation
3. Code aggregated into text view → user adds tasks/warnings
4. Formatted prompt copied to clipboard → pasted into AI
5. AI response parsed in MessageClientView → creates LLMFileUpdate objects
6. DiffPreviewView shows changes → user approves → files updated with backups

### Critical Components
- **MainView**: NavigationSplitView with sidebar/detail pattern
- **MessageClientView**: Parses AI responses (JSON or markdown code blocks)
- **DiffPreviewView**: Side-by-side diff display before applying changes
- **FileMonitor**: Real-time file watching using DispatchSource
- **LogManager**: Singleton for centralized SwiftLog() logging

## Project Structure
- View files are in the main Swift-Prompt directory
- Model and utility files are in subdirectories
- Tests are in Swift-PromptTests directory