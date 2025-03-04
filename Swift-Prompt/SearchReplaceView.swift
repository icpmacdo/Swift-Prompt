//
//  SearchReplaceView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct SearchReplaceView: View {
    @EnvironmentObject var viewModel: ContentViewModel

    @State private var searchText: String = ""
    @State private var replaceText: String = ""
    @State private var showPreview: Bool = true
    @State private var caseSensitive: Bool = true
    @State private var replaceComplete: Bool = false
    @State private var replacementCount: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Search & Replace")
                .font(.title)
                .padding(.top)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Search for", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                TextField("Replace with", text: $replaceText)
                    .textFieldStyle(.roundedBorder)

                Toggle("Case sensitive", isOn: $caseSensitive)
                Toggle("Show preview before replacing", isOn: $showPreview)
            }
            .padding()

            if showPreview && !searchText.isEmpty {
                previewSection
            }

            HStack {
                Button("Cancel") {
                    NSApp.mainWindow?.endSheet(NSApp.mainWindow?.attachedSheet ?? NSWindow())
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Replace All") {
                    performReplace()
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchText.isEmpty || viewModel.textAreaContents.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            if replaceComplete {
                Text("Replaced \(replacementCount) occurrences")
                    .foregroundColor(.green)
                    .padding(.bottom)
            }
        }
        .frame(width: 500, height: 400)
        .background(Color.softBeigeSecondary) // <--- soft tan background
    }

    private var previewSection: some View {
        VStack(alignment: .leading) {
            Text("Preview:")
                .font(.headline)

            ScrollView {
                Text(highlightedPreview)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    // replaced .background(Color.secondary.opacity(0.1))
                    // with the slightly darker tan:
                    .background(Color.softBeigeSecondary)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }

    private var highlightedPreview: AttributedString {
        let content = viewModel.textAreaContents
        guard !searchText.isEmpty else { return AttributedString(content) }

        var attributedString = AttributedString(content)
        let searchOptions: NSString.CompareOptions = caseSensitive ? [] : .caseInsensitive
        var searchPos = content.startIndex

        while let range = content.range(of: searchText, options: searchOptions, range: searchPos..<content.endIndex) {
            if let attributedRange = Range(range, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow
                attributedString[attributedRange].foregroundColor = .black
            }
            searchPos = range.upperBound
        }

        return attributedString
    }

    private func performReplace() {
        let content = viewModel.textAreaContents
        let searchOptions: NSString.CompareOptions = caseSensitive ? [] : .caseInsensitive

        let newContent = content.replacingOccurrences(of: searchText,
                                                      with: replaceText,
                                                      options: searchOptions)

        replacementCount = content.components(separatedBy: searchText).count - 1
        viewModel.textAreaContents = newContent

        replaceComplete = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                replaceComplete = false
            }
        }

        // Close the sheet after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSApp.mainWindow?.endSheet(NSApp.mainWindow?.attachedSheet ?? NSWindow())
        }
    }
}

struct SearchReplaceView_Previews: PreviewProvider {
    static var previews: some View {
        SearchReplaceView()
            .environmentObject(ContentViewModel())
    }
}
