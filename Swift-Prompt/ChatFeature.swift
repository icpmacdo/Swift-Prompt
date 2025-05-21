//
//  ChatFeature.swift
//  SwiftPrompt
//
//  Created by Ian MacDonald on 2025-02-01.
//

import SwiftUI
import AppKit

// MARK: - ChatMessage Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - ChatFeatureViewModel
/// Example ViewModel holding chat messages, pinned messages, and methods to simulate or request an LLM response.
class ChatFeatureViewModel: ObservableObject {
    // Published properties that your View observes:
    @Published var messages: [ChatMessage] = []
    @Published var pinnedMessages: [ChatMessage] = []
    @Published var isSending: Bool = false
    @Published var showTypingIndicator: Bool = false
    @Published var showCopyBanner: Bool = false
    @Published var showPinnedBanner: Bool = false
    @Published var pinnedBannerText: String = ""
    
    @Published var folderURL: URL? = nil
    
    // Toggle for “Use Prompt Framework”
    @Published var usePromptFramework: Bool = false
    
    // Helper array storing message history for API calls.
    // This is intended to be sent with requests to the LLM to provide conversation context.
    // Each dictionary should conform to the expected format of the target LLM API
    // (e.g., `["role": "user", "content": "Hello"]`, `["role": "assistant", "content": "Hi there!"]`).
    // Currently, it's populated but not used by the simulated response logic.
    private var messageHistory: [[String: String]] = []
    
    // MARK: - Chat methods
    func sendUserMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let msg = ChatMessage(content: text, isUser: true, timestamp: Date())
        messages.append(msg)
        messageHistory.append(["role": "user", "content": text])
    }
    
    // MARK: - LLM Interaction (Currently Simulated)
    // TODO: Replace with actual LLM API call.
    // This method currently simulates an LLM response with a delay.
    // A real implementation would involve:
    // 1. Managing API keys securely.
    // 2. Constructing a request payload, potentially including conversation history (`messageHistory`).
    // 3. Making an asynchronous network call to an LLM service (e.g., OpenAI, Anthropic).
    // 4. Parsing the response (which might be JSON, streaming text, etc.).
    // 5. Handling various network and API errors robustly.
    // 6. Updating the UI with the actual response or error.
    func requestLLMResponse(for userText: String) {
        isSending = true
        showTypingIndicator = true
        
        // Example of a simulated async call to an LLM
        Task {
            do {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                let response = "Hello from the LLM! (Simulated)"
                let assistantMsg = ChatMessage(content: response, isUser: false, timestamp: Date())
                
                await MainActor.run {
                    self.messages.append(assistantMsg)
                    self.isSending = false
                    self.showTypingIndicator = false
                }
                
            } catch {
                let errMsg = "Error: \(error.localizedDescription)"
                let sysMsg = ChatMessage(content: errMsg, isUser: false, timestamp: Date())
                await MainActor.run {
                    self.messages.append(sysMsg)
                    self.isSending = false
                    self.showTypingIndicator = false
                }
            }
        }
    }
    
    /// For quick demonstration, “simulate” a short JSON code-block response
    func simulateLLMResponse() {
        let sample = """
        [ {
          "fileName": "FakeFile.swift",
          "code": "// Updated code\\nimport Foundation\\n..."
        } ]
        """
        let msg = ChatMessage(content: sample, isUser: false, timestamp: Date())
        messages.append(msg)
    }
    
    func togglePin(for msg: ChatMessage) {
        if let idx = pinnedMessages.firstIndex(where: { $0.id == msg.id }) {
            pinnedMessages.remove(at: idx)
            showPinnedStatus(text: "Unpinned!")
        } else {
            pinnedMessages.append(msg)
            showPinnedStatus(text: "Pinned!")
        }
    }
    
    private func showPinnedStatus(text: String) {
        pinnedBannerText = text
        withAnimation { showPinnedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { self.showPinnedBanner = false }
        }
    }
    
    func clearChat() {
        messages.removeAll()
        pinnedMessages.removeAll()
    }
}

// MARK: - ChatFeatureView
/// A SwiftUI View that displays messages, pinned messages, and a text field for user input.
struct ChatFeatureView: View {
    // IMPORTANT: Explicitly type your EnvironmentObject to ChatFeatureViewModel
    @EnvironmentObject var viewModel: ChatFeatureViewModel
    
    @State private var userInput: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top row: toggle + simulate button
                HStack {
                    Toggle("Use Prompt Framework", isOn: $viewModel.usePromptFramework)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Simulate LLM") {
                        viewModel.simulateLLMResponse()
                    }
                    .buttonStyle(.bordered)
                    .padding(.trailing)
                }
                .padding(.top, 8)
                
                // Show pinned messages in a horizontal scroller
                if !viewModel.pinnedMessages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.pinnedMessages) { pinned in
                                Text(pinned.content)
                                    .font(.footnote)
                                    .padding(6)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.05))
                }
                
                // Scrollable chat history
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.messages) { msg in
                                MessageBubble(
                                    message: msg,
                                    isPinned: viewModel.pinnedMessages.contains(where: { $0.id == msg.id }),
                                    copyAction: { copyToClipboard(msg.content) },
                                    pinAction: { viewModel.togglePin(for: msg) }
                                )
                                .id(msg.id)
                            }
                            
                            if viewModel.showTypingIndicator {
                                TypingIndicatorBubble()
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastID = viewModel.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                // Input area with a text field & send button
                inputArea
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Clear all messages")
                }
            }
            .overlay(ephemeralBanners, alignment: .top)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Input Area
extension ChatFeatureView {
    private var inputArea: some View {
        HStack {
            TextField("Type a message...", text: $userInput, axis: .vertical)
                .focused($isTextFieldFocused)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit {
                    sendMessage()
                }
            
            if viewModel.isSending {
                ProgressView()
                    .frame(width: 24, height: 24)
                    .padding(.leading, 8)
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .rotationEffect(.degrees(45))
                }
                .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.leading, 8)
            }
        }
        .padding()
    }
    
    private func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1) Add user message
        viewModel.sendUserMessage(trimmed)
        
        // 2) Make an LLM request
        viewModel.requestLLMResponse(for: trimmed)
        
        // 3) Clear the text field
        userInput = ""
        isTextFieldFocused = false
    }
}

// MARK: - Ephemeral Banners
extension ChatFeatureView {
    @ViewBuilder
    fileprivate var ephemeralBanners: some View {
        VStack {
            if viewModel.showCopyBanner {
                Text("Copied to clipboard!")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                    .transition(.move(edge: .top))
            }
            if viewModel.showPinnedBanner {
                Text(viewModel.pinnedBannerText)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange.opacity(0.9))
                    .cornerRadius(8)
                    .transition(.move(edge: .top))
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Copy to Clipboard
extension ChatFeatureView {
    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        
        // Show ephemeral "Copied" banner
        Task {
            await MainActor.run { viewModel.showCopyBanner = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation {
                    viewModel.showCopyBanner = false
                }
            }
        }
    }
}

// MARK: - Helper Bubbles
struct MessageBubble: View {
    let message: ChatMessage
    let isPinned: Bool
    var copyAction: (() -> Void)?
    var pinAction: (() -> Void)?
    
    var body: some View {
        HStack {
            if !message.isUser {
                avatar(isUser: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(message.isUser ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(12)
                    .frame(maxWidth: 250, alignment: message.isUser ? .trailing : .leading)
                
                Text(Self.formattedDate(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding([.leading, .trailing], 8)
                    .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            }
            if message.isUser {
                avatar(isUser: true)
            }
        }
        .padding(.horizontal)
        .contextMenu {
            Button("Copy") { copyAction?() }
            Button(isPinned ? "Unpin" : "Pin") { pinAction?() }
        }
    }
    
    private func avatar(isUser: Bool) -> some View {
        Image(systemName: isUser ? "person.circle.fill" : "bubble.left")
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .foregroundColor(isUser ? .blue : .gray)
            .padding(.horizontal, 4)
    }
    
    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            Image(systemName: "bubble.left")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            VStack(alignment: .leading) {
                Text("Typing...")
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .frame(maxWidth: 250, alignment: .leading)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}
