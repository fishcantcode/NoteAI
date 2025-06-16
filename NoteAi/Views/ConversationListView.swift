import SwiftUI

struct ConversationListView: View {
    @StateObject var viewModel = ConversationListViewModel()
    @State private var showingCreateConversation = false
    @State private var newConversationName = ""
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                } else if viewModel.conversations.isEmpty {
                    Text("No conversations yet")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.conversations) { conversation in
                        NavigationLink(destination: ChatView(conversationId: conversation.id)) {
                            ConversationRow(conversation: conversation)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                viewModel.loadConversations()
            }
            .navigationTitle("Conversations")

            .overlay {
                if viewModel.isCreatingConversation {
                    ProgressView("Creating conversation...")
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
            }
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.name)
                .font(.headline)
                .lineLimit(1)
            
            Text(conversation.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationListView()
}
