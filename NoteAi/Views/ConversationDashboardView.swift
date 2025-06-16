import SwiftUI

struct ConversationDashboardView: View {
    @ObservedObject var viewModel: FolderDetailViewModel
    let summaryDocument: Document
    @State private var summaryContent: String? // To hold the loaded summary
    @State private var isLoadingContent = false // Loading state for content
    @State private var contentLoadError: String? // Error state for content loading

    var body: some View {
        VStack(spacing: 20) {
            // Document info header
            VStack(alignment: .leading, spacing: 8) {
                Text("Document: \(summaryDocument.name)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Created: \(summaryDocument.creationDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let docId = summaryDocument.difyConversationId {
                    Text("Document ID: \(docId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Content loading status
            if isLoadingContent {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading document content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let error = contentLoadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Content loading error: \(error)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if summaryContent != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Document content loaded successfully")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Chat options section
            VStack(spacing: 16) {
                if let existingConversationId = summaryDocument.difyConversationId {
                    // Define chatViewForExisting INSIDE the scope where existingConversationId is available
                    let chatViewForExisting = ChatView(
                        conversationId: existingConversationId,
                        sourceDocumentId: summaryDocument.difyConversationId, // Pass document ID
                        documentContext: summaryContent, // Pass loaded summary content
                        onNewConversationCreated: { newIdInClosure in // Renamed to avoid conflict if any
                            viewModel.saveDifyConversationId(for: summaryDocument, difyId: newIdInClosure)
                        }
                    )
                    NavigationLink(destination: chatViewForExisting) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Continue Existing Conversation")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                } else {
                    Text("No existing conversation found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(12)
                }

                // Prepare ChatView for a new conversation, passing the document context
                let chatViewForNew = ChatView(
                    conversationId: nil, 
                    sourceDocumentId: summaryDocument.id.uuidString, // Use document.id for new chats consistently for sourceDocumentId
                    documentContext: summaryContent, // Pass loaded summary content
                    onNewConversationCreated: { newIdInClosure in // Renamed to avoid conflict
                        viewModel.saveDifyConversationId(for: summaryDocument, difyId: newIdInClosure)
                    }
                )

                NavigationLink(destination: chatViewForNew) {
                    HStack {
                        Image(systemName: "plus.bubble.fill")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Start New AI Chat")
                                .font(.headline)
                        }
                        Spacer()
                        if summaryContent == nil && !isLoadingContent {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(summaryContent != nil ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(summaryContent == nil && !isLoadingContent) // Disable if no content loaded
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Chat Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDocumentContent()
        }
        .refreshable {
            loadDocumentContent()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDocumentContent() {
        guard summaryContent == nil else { return } // Don't reload if already loaded
        
        isLoadingContent = true
        contentLoadError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try DocumentManager.shared.readTextFromFile(fileName: summaryDocument.name)
                DispatchQueue.main.async {
                    self.summaryContent = content
                    self.isLoadingContent = false
                    print("✅ Successfully loaded document content for: \(summaryDocument.name)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.contentLoadError = error.localizedDescription
                    self.isLoadingContent = false
                    print("❌ Error loading document content: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ConversationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
         
        let mockAPIManager = APIManager()
        let mockDataset = KnowledgeDataset(
            id: "preview_dataset_1",
            name: "Sample Knowledge Base",
            description: "This is a sample knowledge base for preview purposes.",
            permission: "only_me",
            indexingTechnique: "high_quality",
            createdAt: Int(Date().timeIntervalSince1970)
        )
        let mockViewModel = FolderDetailViewModel(dataset: mockDataset, apiManager: mockAPIManager)
        let mockDocumentWithConversation = Document(id: UUID(), name: "Summary with Chat", type: .note, creationDate: Date(), url: URL(string: "file:///mocksummarywithchat.txt")!, difyConversationId: "existing-convo-123")
        let mockDocumentWithoutConversation = Document(id: UUID(), name: "Summary without Chat", type: .note, creationDate: Date(), url: URL(string: "file:///mocksummarywithoutchat.txt")!, difyConversationId: nil)


        return NavigationView {
            VStack {
                ConversationDashboardView(viewModel: mockViewModel, summaryDocument: mockDocumentWithConversation)
                ConversationDashboardView(viewModel: mockViewModel, summaryDocument: mockDocumentWithoutConversation)
            }
            
        }
    }
}
