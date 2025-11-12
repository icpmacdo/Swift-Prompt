//
//  ConsoleLogView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct ConsoleLogView: View {
    @ObservedObject var logManager = LogManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with clear button and stats
            HStack {
                Text("Console Log")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(logManager.logLineCount) lines • \(formatBytes(logManager.logSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: {
                    logManager.clear()
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(logManager.logs.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.softBeigeSecondary.opacity(0.5))

            Divider()

            // Log content
            ScrollView {
                Text(logManager.logs)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.softBeigeSecondary)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}
