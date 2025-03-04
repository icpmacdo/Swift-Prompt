//
//  MultiSelectDropdown.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct MultiSelectDropdown: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>
    
    @State private var isExpanded = false
    @State private var searchText = ""

    var filtered: [String] {
        if searchText.isEmpty { return options }
        return options.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    if selectedOptions.isEmpty {
                        Text(title).foregroundColor(.secondary)
                    } else {
                        Text(
                            selectedOptions.prefix(3).joined(separator: ", ")
                            + (selectedOptions.count > 3
                               ? " +\(selectedOptions.count - 3) more"
                               : "")
                        )
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .padding()
                .background(Color.softBeigeSecondary.opacity(0.6)) // <--- changed
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search...", text: $searchText)
                }
                .padding(8)
                .background(Color.softBeigeSecondary.opacity(0.3))
                .cornerRadius(8)

                HStack {
                    Button("Select All") {
                        selectedOptions = Set(options)
                    }
                    .disabled(selectedOptions.count == options.count)
                    Spacer()
                    Button("Deselect All") {
                        selectedOptions.removeAll()
                    }
                    .disabled(selectedOptions.isEmpty)
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filtered, id: \.self) { opt in
                            Button {
                                if selectedOptions.contains(opt) {
                                    selectedOptions.remove(opt)
                                } else {
                                    selectedOptions.insert(opt)
                                }
                            } label: {
                                HStack {
                                    Text(opt)
                                    Spacer()
                                    if selectedOptions.contains(opt) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(
                                    selectedOptions.contains(opt)
                                    ? Color.accentColor.opacity(0.1)
                                    : Color.clear
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 200)
                .background(Color.softBeigeSecondary.opacity(0.2)) // <--- changed
                .cornerRadius(8)
            }
        }
        .animation(.easeInOut, value: isExpanded)
        .background(Color.clear)
        .cornerRadius(10)
    }
}
