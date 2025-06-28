# Swift-Prompt User Guide

## Table of Contents
1. [Overview](#overview)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Features](#features)
5. [Export Formats](#export-formats)
6. [Keyboard Shortcuts](#keyboard-shortcuts)
7. [Troubleshooting](#troubleshooting)
8. [Security](#security)
9. [Performance Tips](#performance-tips)

## Overview

Swift-Prompt is a powerful macOS application that helps developers aggregate code files from their projects into AI-friendly prompts. It's designed to make it easy to share your codebase with AI assistants like Claude, ChatGPT, or other LLMs for code reviews, refactoring suggestions, or development assistance.

### Key Features
- 📁 Aggregate multiple code files into a single prompt
- 🎯 Smart file filtering by extension
- 📋 Multiple export formats (XML, JSON, Markdown, Raw)
- ✅ Task and warning management
- 🔍 Real-time file monitoring
- 💻 Multi-language code parsing
- 🔒 Security-focused design
- ⚡ Concurrent file processing

## Installation

### System Requirements
- macOS 12.0 (Monterey) or later
- Xcode 15.0 or later (for building from source)

### Installing from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Swift-Prompt.git
   cd Swift-Prompt
   ```

2. Open in Xcode:
   ```bash
   open Swift-Prompt.xcodeproj
   ```

3. Build and run:
   - Press `⌘+R` or click the Run button in Xcode

### First Launch
On first launch, macOS may ask for permissions to:
- Access folders on your disk
- Read files in selected directories

Grant these permissions for Swift-Prompt to function properly.

## Getting Started

### 1. Select a Project Folder
Click the "Browse" button in the sidebar to select your project folder. Swift-Prompt will:
- Remember your selection using secure bookmarks
- Display the folder structure in the sidebar
- Begin monitoring for file changes

### 2. Choose File Types
Use the file type selector to choose which files to include:
- Select specific extensions (swift, js, py, etc.)
- Use "*" to include all file types
- Your selections are saved between sessions

### 3. Add Tasks and Warnings (Optional)
Click "Task List, Warnings & Actions" to add:
- **Tasks**: What you want the AI to help with
- **Warnings**: Important constraints or considerations

### 4. Select Export Format
Choose your preferred format from the segmented control:
- **XML**: Structured format with metadata
- **JSON**: Machine-readable format
- **Markdown**: Human-readable with syntax highlighting
- **Raw**: Simple text format

### 5. Copy and Use
Click "Copy With Tasks" to copy the formatted prompt to your clipboard, then paste it into your AI assistant.

## Features

### File Filtering
Swift-Prompt automatically excludes:
- Hidden files (starting with .)
- Common build directories (node_modules, dist, build)
- Version control folders (.git)
- Binary files

### Real-time Monitoring
The app watches your selected folder for changes:
- New files are automatically detected
- Modified files trigger a refresh option
- Deleted files are removed from the list

### Multi-Language Support
The response parser supports code blocks in:
- Swift, JavaScript, TypeScript
- Python, Java, Kotlin
- HTML, CSS, JSON, XML
- Ruby, Go, Rust, C/C++
- Shell scripts and more

### Diff Preview
When applying AI-suggested changes:
1. Paste the AI response in the Message Client tab
2. Click "Parse & Apply Updates"
3. Review the side-by-side diff
4. Apply or cancel changes

## Export Formats

### XML Format
```xml
<?xml version="1.0" encoding="UTF-8"?>
<prompt version="1.0">
  <metadata>
    <timestamp>2025-01-28T10:30:00Z</timestamp>
    <project>MyApp</project>
    <fileCount>5</fileCount>
  </metadata>
  <tasks>
    <task priority="high">Refactor UserManager</task>
  </tasks>
  <files>
    <file>
      <path>UserManager.swift</path>
      <language>swift</language>
      <content><![CDATA[...]]></content>
    </file>
  </files>
</prompt>
```

### JSON Format
```json
{
  "version": "1.0",
  "metadata": {
    "timestamp": "2025-01-28T10:30:00Z",
    "project": "MyApp",
    "fileCount": 5
  },
  "tasks": [
    {"priority": "high", "content": "Refactor UserManager"}
  ],
  "files": [
    {
      "path": "UserManager.swift",
      "language": "swift",
      "content": "..."
    }
  ]
}
```

### Markdown Format
```markdown
# Code Export

## Metadata
- **Project**: MyApp
- **Timestamp**: January 28, 2025
- **Files**: 5

## Tasks
- 🔴 High: Refactor UserManager

## Files

### UserManager.swift
```swift
// File content here
```
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘+O | Open folder |
| ⌘+C | Copy code with selected format |
| ⌘+R | Refresh current folder |
| ⌘+F | Search (coming soon) |
| ⌘+, | Open preferences |

## Troubleshooting

### Common Issues

#### "No files found"
- Check your file type filters
- Ensure the folder contains supported file types
- Verify folder permissions

#### "Access denied to file"
1. Re-select the folder to refresh permissions
2. Check System Preferences > Security & Privacy > Files and Folders
3. Grant Swift-Prompt access to the folder

#### "File too large"
- Files over 10MB are skipped by default
- Split large files or increase the limit in preferences
- Consider excluding generated files

#### XML/JSON Export Shows Empty
- Ensure files are properly formatted with the expected delimiters
- Check that tasks/warnings don't contain special characters
- Try the Raw format as a fallback

### Error Messages

#### Path Traversal Detected
- Security feature preventing access outside the selected folder
- Only use relative paths within your project

#### Bookmark Creation Failed
- macOS security feature issue
- Try selecting the folder again
- Restart the app if the issue persists

## Security

Swift-Prompt prioritizes security:

### Sandboxing
- Only accesses folders you explicitly select
- Uses macOS security-scoped bookmarks
- Cannot access system files without permission

### Path Validation
- Prevents path traversal attacks (../)
- Validates all file paths before access
- Restricts access to selected folder only

### Data Handling
- No data is sent to external servers
- All processing happens locally
- Clipboard operations are explicit

## Performance Tips

### For Large Projects
1. **Use specific file filters** instead of "*"
2. **Exclude build directories** (automatically done)
3. **Process in batches** for very large codebases
4. **Close other applications** to free up memory

### Optimization Features
- Concurrent processing of up to 10 files
- Progress indicators with percentages
- Lazy loading of file contents
- Efficient memory management

### Best Practices
- Keep your codebase organized
- Use consistent file extensions
- Avoid extremely large single files
- Regular cleanup of build artifacts

## Advanced Usage

### Custom File Patterns
While the UI shows common extensions, you can:
- Add custom extensions through the dropdown
- Use the "*" wildcard for all files
- Combine multiple selections

### Backup System
When applying changes:
- Original files are backed up with timestamps
- Backups are stored in the same directory
- Format: `filename.ext.backup-1234567890`

### Integration Tips
- Save common task templates
- Use consistent formatting in your code
- Add file headers for better AI context
- Keep sensitive data in separate files

---

For more help, visit our [GitHub repository](https://github.com/yourusername/Swift-Prompt) or file an issue.