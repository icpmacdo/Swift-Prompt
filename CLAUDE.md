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

## Project Structure
- View files are in the main Swift-Prompt directory
- Model and utility files are in subdirectories
- Tests are in Swift-PromptTests directory