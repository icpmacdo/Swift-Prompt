# Swift-Prompt Codebase Documentation

## Overview

Swift-Prompt is a macOS application that aggregates code files for AI-assisted development. It provides a clean interface for selecting folders, filtering files, formatting prompts, and applying AI-suggested code changes with safety features like diff preview and backup creation.

## Architecture

### Core Design Pattern: MVVM with SwiftUI

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Views (UI)    │────▶│  ViewModels      │────▶│     Models      │
│                 │     │  (@MainActor)    │     │                 │
│ - MainView      │     │ - ContentViewModel│     │ - FolderNode    │
│ - SidebarView   │     │                  │     │ - LLMFileUpdate │
│ - CodeDetailView│     │                  │     │ - PromptData    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌──────────────────┐
                        │    Utilities     │
                        │ - FileMonitor    │
                        │ - LogManager     │
                        └──────────────────┘
```

### State Management

1. **ContentViewModel** (@MainActor, @Observable): Central state container
   - Manages folder selection and security-scoped bookmarks
   - Handles file type filtering with UserDefaults persistence
   - Monitors file changes via FileMonitor
   - Aggregates code and manages UI state

2. **PromptData** (ObservableObject): Prompt configuration
   - Stores tasks and warnings for AI instructions
   - Passed as @EnvironmentObject through view hierarchy

### Key Components

#### File Selection & Monitoring
- **Folder Selection**: NSOpenPanel with security-scoped bookmarks
- **File Monitoring**: DispatchSource-based real-time updates
- **Exclusions**: Automatic filtering of .git, node_modules, dist, build
- **Type Filtering**: Dynamic discovery with customizable selection

#### Prompt Formatting System

##### Current Issues (CRITICAL)
- `createXML()` function returns empty string - core functionality broken
- No actual formatting despite "Wrap in XML" toggle
- Tasks and warnings collected but never used

##### Proposed Multi-Format System

**1. XML Format** (Structured for AI consumption)
```xml
<prompt version="1.0">
  <context>
    <project-name>MyApp</project-name>
    <timestamp>2024-01-20T10:30:00Z</timestamp>
    <file-count>15</file-count>
  </context>
  
  <instructions>
    <task priority="high">Refactor UserManager to use async/await</task>
    <constraint>Maintain iOS 14 compatibility</constraint>
  </instructions>
  
  <codebase>
    <file path="Sources/UserManager.swift" language="swift" lines="145">
      <![CDATA[
        // File contents here
      ]]>
    </file>
  </codebase>
</prompt>
```

**2. Markdown Format** (Human-readable)
```markdown
# Code Review Request

## Tasks
1. 🔴 **High Priority**: Refactor UserManager to use async/await

## Constraints
- ⚠️ Maintain iOS 14 compatibility

## Codebase

### `Sources/UserManager.swift` (145 lines)
```swift
// File contents
```
```

**3. JSON Format** (Machine-parseable)
```json
{
  "version": "1.0",
  "context": {
    "projectName": "MyApp",
    "fileCount": 15
  },
  "instructions": {
    "tasks": [{"priority": "high", "description": "..."}],
    "constraints": ["..."]
  },
  "codebase": [
    {
      "path": "Sources/UserManager.swift",
      "language": "swift",
      "content": "..."
    }
  ]
}
```

#### Response Parsing System

##### Current Implementation
- Basic regex: `#"```(?:swift)?\s*(?:\w+\.swift)?\s*([\w/\-\.]+\.swift)(?:\s*|\n)([\s\S]*?)```"#`
- Only supports Swift files
- No error recovery
- Limited format support

##### Enhanced Parser Design

**Flexible Pattern Matching**
```swift
class EnhancedResponseParser {
    private let patterns = [
        // Standard: ```language filename
        #"```(\w+)?\s*\n?([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
        
        // Filename as comment: ```language\n// filename
        #"```(\w+)?\s*\n(?://|#|--)\s*([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
        
        // Combined: ```language:filename
        #"```(\w+):([^\n]+\.\w+)\s*\n([\s\S]*?)```"#,
        
        // With operation: ```language filename [CREATE/UPDATE/DELETE]
        #"```(\w+)?\s*\n?([^\n]+\.\w+)\s*\[(\w+)\]\s*\n([\s\S]*?)```"#
    ]
}
```

**Format Auto-Detection**
- JSON detection for structured responses
- XML parsing for formatted responses
- Markdown code block extraction
- Automatic fallback between formats

#### Diff Preview & Application

**Current**: Basic line-by-line diff display
**Enhanced**: 
- Syntax highlighting
- Semantic diff understanding
- Partial file updates
- Transaction-based application with rollback

### File Structure

```
Swift-Prompt/
├── Swift-Prompt/
│   ├── Views/
│   │   ├── MainView.swift              # Primary navigation structure
│   │   ├── SidebarView.swift           # Folder selection & filtering
│   │   ├── CodeDetailView.swift        # Code aggregation display
│   │   ├── MessageClientView.swift     # AI response parsing
│   │   ├── DiffPreviewView.swift       # Change preview
│   │   └── Supporting Views...
│   │
│   ├── Models/
│   │   ├── FolderNode.swift            # File tree representation
│   │   ├── LLMFileUpdate.swift         # File change model
│   │   └── PromptData.swift            # Task/warning storage
│   │
│   ├── ViewModels/
│   │   └── ContentViewModel.swift      # Main business logic
│   │
│   ├── Utilities/
│   │   ├── FileMonitor.swift           # File system watching
│   │   ├── LogManager.swift            # Centralized logging
│   │   └── PromptFormatting.swift      # Export formatting
│   │
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── theme.swift                 # Color definitions
│       └── Swift-Prompt.entitlements   # App permissions
│
├── Swift-PromptTests/
└── Swift-PromptUITests/
```

## Key User Flows

### 1. Code Aggregation Flow
```
User selects folder → 
ContentViewModel creates security bookmark → 
FileMonitor starts watching → 
Files enumerated with exclusions → 
Code aggregated into text view
```

### 2. Prompt Creation Flow
```
User adds tasks/warnings → 
Selects format (XML/Markdown/JSON) → 
createFinalExportText() generates formatted prompt → 
Copied to clipboard → 
Pasted into AI tool
```

### 3. Response Application Flow
```
User pastes AI response → 
EnhancedResponseParser detects format → 
Extracts file updates → 
Validates changes → 
Shows diff preview → 
User approves → 
Creates backups → 
Applies changes
```

## Security Considerations

### App Sandbox
- Read/write access to user-selected files only
- Security-scoped bookmarks for persistent access
- No network access (currently)

### File Safety
- Automatic backups before modifications
- Path validation to prevent directory traversal
- Content validation for dangerous patterns
- Fallback to Documents folder if write fails

## Performance Optimizations

### Current
- File enumeration on background queue
- Debounced file monitoring
- Lazy loading of file contents

### Planned
- Streaming response parsing
- Incremental file updates
- Parallel validation
- Smart caching of parsed responses

## Testing Strategy

### Unit Tests
- Parser pattern matching
- Validation logic
- File operation safety

### Integration Tests
- Full flow from selection to application
- Error recovery scenarios
- Concurrent modification handling

### UI Tests
- Critical user workflows
- Accessibility compliance
- Keyboard navigation

## Future Enhancements

### High Priority
1. Fix XML formatting (critical bug)
2. Direct AI API integration
3. Enhanced file filtering (.gitignore support)
4. Project templates and saved configurations

### Medium Priority
1. Syntax highlighting in diffs
2. Multi-model support (Claude, GPT, Gemini)
3. Streaming responses
4. Plugin system

### Low Priority
1. Command-line interface
2. Team collaboration features
3. Analytics and metrics
4. Custom AI providers

## Development Guidelines

### Code Style
- 4-space indentation
- 100 character line limit
- Use `@ViewBuilder` for complex views
- Extract subviews to extensions
- Prefer computed properties over functions for views

### Error Handling
- Use descriptive error types
- Log with SwiftLog() utility
- Show user-friendly error messages
- Provide recovery suggestions

### Testing
- Test file operations with mocks
- Validate all parsing patterns
- Check error paths
- Ensure accessibility

## Common Tasks

### Adding a New File Type
1. Update file extension list in ContentViewModel
2. Add syntax highlighting rules if needed
3. Create appropriate validator
4. Update parser patterns

### Adding a New Export Format
1. Add case to PromptFormat enum
2. Implement formatting function
3. Add UI picker option
4. Create tests

### Debugging File Monitoring
1. Check console logs via LogManager
2. Verify security-scoped bookmark validity
3. Test with FileMonitor notifications
4. Check exclusion patterns

## Dependencies

Currently using only Apple frameworks:
- SwiftUI
- Foundation
- UniformTypeIdentifiers
- OSLog

No third-party dependencies, keeping the app lightweight and secure.