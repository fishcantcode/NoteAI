import SwiftUI

struct ChatView: View {
    
    let conversationId: String?
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var scrollTarget: String?
    @State private var showRecordingError = false
    @Environment(\.presentationMode) var presentationMode
    
    
    var onNewConversationCreated: ((String) -> Void)?
    
    init(conversationId: String?, onNewConversationCreated: ((String) -> Void)? = nil) {
        self.conversationId = conversationId
        self.onNewConversationCreated = onNewConversationCreated
        
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversationId,
            onNewConversationCreated: onNewConversationCreated
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            /*
             HStack {
             Text("Response Mode:")
             .font(.caption)
             
             Picker("Response Mode", selection: $viewModel.responseMode) {
             Text("Blocking").tag("blocking")
             Text("Streaming").tag("streaming")
             }
             .pickerStyle(SegmentedPickerStyle())
             .frame(width: 200)
             }
             .padding(.horizontal)
             .padding(.top, 8)
             */
            
            
            ScrollViewReader { scrollView in
                List(viewModel.messages, id: \.id) { message in
                    MessageRow(message: message)
                        .id(message.id)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        VStack {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                                .padding()
                            Text("No Messages")
                                .font(.headline)
                            Text("Start a conversation by sending a message")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }
                .onChange(of: viewModel.messages) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
            }
            
            
            if viewModel.showLongWaitingAlert {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Response is taking longer than expected (\(viewModel.waitingTimeSeconds)s)")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
            }
            
            
            VStack(spacing: 8) {
                if viewModel.isRecording && !viewModel.isFinished {
                    HStack {
                        Text(viewModel.isDetectingSpeech ? "Waiting for speech..." : "Listening...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%d:%02d", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    if viewModel.isRecording && !viewModel.isFinished {
                        Button(action: { viewModel.stopRecording() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.orange)
                        }
                        .disabled(viewModel.isProcessing)

                        Button(action: { viewModel.finishRecording() }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        }
                        .disabled(viewModel.isProcessing)
                    } else {
                        Button(action: { viewModel.startRecording() }) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                        }
                        .disabled(viewModel.isProcessing) 
                    }
                    
                    TextField("Type a message...", text: $messageText)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                        .disabled(viewModel.isLoading || viewModel.isRecording)
                    
                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isRecording {
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(viewModel.isLoading ? .gray : .blue)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle("Chat")
        .navigationBarBackButtonHidden(viewModel.isLoading)
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let messageToSend = messageText
        messageText = ""
        viewModel.sendMessage(messageToSend)
    }
} 

struct MessageRow: View {
        let message: Message
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                
                if !message.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(message.query)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                            Text(message.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !message.cleanAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.cleanAnswer)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                            
                            let resources = message.retrieverResources
                            if !resources.isEmpty {
                                ResourcesView(resources: resources)
                                    .padding(.top, 4)
                            }
                            if message.status == "sending" {
                                Text("Sending...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if message.status == "error" {
                                Text("Error: \(message.error ?? "Unknown error")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text(message.formattedDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    struct ResourcesView: View {
        let resources: [RetrieverResource]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sources")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(resources) { resource in
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = resource.title {
                            Text(title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        if let segment = resource.segment {
                            Text(segment)
                                .font(.caption2)
                                .lineLimit(3)
                        }
                        
                        if let source = resource.source {
                            Text(source)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
        }
    }
    
    #Preview {
        NavigationView {
            
            ChatView(conversationId: "preview-id-123", onNewConversationCreated: { newId in
                print("Preview: New conversation created with ID: \(newId)")
            })
        }
    }

