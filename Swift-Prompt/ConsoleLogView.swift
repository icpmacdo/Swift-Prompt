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
        ScrollView {
            Text(logManager.logs)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.black)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // changed from .background(Color.black.opacity(0.8)) to:
        .background(Color.softBeigeSecondary)
    }
}
