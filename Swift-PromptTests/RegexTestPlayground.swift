import Foundation

// Test the regex pattern issue
let testContent = """
// TestFile.swift

func helloWorld() {
    print("Hello, World!")
}

// --- End of TestFile.swift ---

"""

// Current broken pattern
let brokenPattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#

// Fixed pattern that accounts for the newline after filename
let fixedPattern = #"// ([^\n]+)\n\n([\s\S]*?)\n\n// --- End of \1 ---"#

print("Testing patterns...")
print("Test content:")
print(testContent)
print("\n---\n")

do {
    let regex = try NSRegularExpression(pattern: fixedPattern, options: [])
    let matches = regex.matches(in: testContent, range: NSRange(testContent.startIndex..., in: testContent))
    
    print("Number of matches: \(matches.count)")
    
    for match in matches {
        if match.numberOfRanges >= 3,
           let filenameRange = Range(match.range(at: 1), in: testContent),
           let contentRange = Range(match.range(at: 2), in: testContent) {
            let filename = String(testContent[filenameRange])
            let content = String(testContent[contentRange])
            print("Filename: \(filename)")
            print("Content: \(content)")
        }
    }
} catch {
    print("Regex error: \(error)")
}