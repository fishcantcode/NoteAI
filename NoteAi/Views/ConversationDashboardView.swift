import SwiftUI

struct ConversationDashboardView: View {
    @ObservedObject var viewModel: FolderDetailViewModel
    let summaryDocument: Document

    var body: some View {
        VStack(spacing: 20) {
            Text("Chat Options for: \(summaryDocument.name)")
                .font(.title2)
                .padding()

            if let existingConversationId = summaryDocument.difyConversationId {
                NavigationLink(destination: ChatView(conversationId: existingConversationId, onNewConversationCreated: { newId in
                     
                     
                    viewModel.saveDifyConversationId(for: summaryDocument, difyId: newId)
                })) {
                    Text("View Current Conversation")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Text("No active conversation for this summary.")
                    .foregroundColor(.secondary)
            }

            NavigationLink(destination: ChatView(conversationId: nil, onNewConversationCreated: { newId in 
                 
                 
                viewModel.saveDifyConversationId(for: summaryDocument, difyId: newId)
            })) {
                Text("Start New Chat")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Chat Dashboard")
        .navigationBarTitleDisplayMode(.inline)
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
