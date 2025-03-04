//
//  FolderTreeView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct FolderTreeView: View {
    let rootNode: FolderNode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                FolderNodeRow(node: rootNode)
            }
            .padding()
        }
        .background(Color.softBeigeSecondary)
    }
}

struct FolderNodeRow: View {
    @State private var isExpanded: Bool = false
    let node: FolderNode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if node.isDirectory {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isExpanded.toggle()
                            SwiftLog("LOG: Toggling folder '\(node.name)' => \(isExpanded ? "expanded" : "collapsed")")
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 20)
                }
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.text.fill")
                    .foregroundColor(node.isDirectory ? .blue : .gray)
                
                Text(node.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            // changed from Color.primary.opacity(0.04) to:
            .background(Color.softBeigeSecondary.opacity(0.4).cornerRadius(6))
            .onTapGesture {
                if node.isDirectory {
                    withAnimation(.easeInOut) {
                        isExpanded.toggle()
                    }
                }
            }
            .onDrag {
                SwiftLog("LOG: user dragged node => \(node.name)")
                return NSItemProvider(object: node.url as NSURL)
            }
            
            if isExpanded && node.isDirectory {
                ForEach(node.children, id: \.id) { child in
                    FolderNodeRow(node: child)
                        .padding(.leading, 20)
                }
            }
        }
    }
}
