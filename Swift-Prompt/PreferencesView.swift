//
//  PreferencesView.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.largeTitle)
                .padding(.bottom, 10)

            Text("Application preferences will appear here in future versions.")
                .foregroundColor(.secondary)

            Spacer()

            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.softBeigeSecondary)
        .frame(width: 450, height: 200)
    }
}
