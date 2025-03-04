//
//  MainView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: Int = 1

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            TabView(selection: $selectedTab) {
                MessageClientView()
                    .tabItem {
                        Label("LLM Updates", systemImage: "doc.on.doc")
                    }
                    .tag(0)
                CodeDetailView()
                    .tabItem {
                        Label("Code", systemImage: "hammer.fill")
                    }
                    .tag(1)
            }
            // give a base tan background behind the tabs
            .background(Color.softBeigeSecondary)
        }
    }
}
