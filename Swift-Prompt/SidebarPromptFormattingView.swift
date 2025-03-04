//
//  SidebarPromptFormattingView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct SidebarPromptFormattingView: View {
    @EnvironmentObject var promptData: PromptData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goals:")
                .font(.headline)
            PromptTaskListEditor(tasks: $promptData.tasks)

            Divider()

            Text("Warnings:")
                .font(.headline)
            PromptWarningListEditor(warnings: $promptData.warnings)

            Spacer()
        }
        .padding()
        .background(Color.softBeigeSecondary)
    }
}

struct PromptTaskListEditor: View {
    @Binding var tasks: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tasks.indices, id: \.self) { i in
                HStack {
                    TextField("Task \(i+1)", text: $tasks[i])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if tasks.count > 1 {
                        Button {
                            tasks.remove(at: i)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            Button("+ Add Task") {
                tasks.append("")
            }
        }
    }
}

struct PromptWarningListEditor: View {
    @Binding var warnings: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(warnings.indices, id: \.self) { i in
                HStack {
                    TextField("Warning \(i+1)", text: $warnings[i])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if warnings.count > 1 {
                        Button {
                            warnings.remove(at: i)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            Button("+ Add Warning") {
                warnings.append("")
            }
        }
    }
}
