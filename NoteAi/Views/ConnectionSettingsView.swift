import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var apiManager = APIManager.shared

     
    @State private var editableBaseURL: String
    @State private var editableChatAPIKey: String
    @State private var editableKnowledgeAPIKey: String

    init() {
        _editableBaseURL = State(initialValue: ConfigManager.shared.difyBaseURL)
        _editableChatAPIKey = State(initialValue: ConfigManager.shared.difyChatAPIKey)
        _editableKnowledgeAPIKey = State(initialValue: ConfigManager.shared.difyKnowledgeID)
    }

    var body: some View {
        NavigationView {  
            Form {
                Section(header: Text("Server Configuration")) {
                    HStack {
                        Text("Base URL:")
                        TextField("Enter Base URL", text: $editableBaseURL)
                            .autocorrectionDisabled(true)
                    }
                    HStack {
                        Text("Chat API Key:")
                        TextField("Enter Chat API Key", text: $editableChatAPIKey)
                            .autocorrectionDisabled(true)
                    }
                    HStack {
                        Text("Knowledge API Key:")
                        TextField("Enter Knowledge API Key", text: $editableKnowledgeAPIKey)
                            .autocorrectionDisabled(true)
                    }
                    Button("Apply Configuration") {
                        ConfigManager.shared.difyBaseURL = editableBaseURL
                        ConfigManager.shared.difyChatAPIKey = editableChatAPIKey
                        ConfigManager.shared.difyKnowledgeID = editableKnowledgeAPIKey
                         
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(Color("MainColor"))
                }

                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Overall Status:")
                        Spacer()
                        ConnectionStatusIndicator()  
                    }
                    if apiManager.overallConnectionStatus == .partial {
                        Text("Chat Service: \(apiManager.chatServiceStatus ? "Connected" : "Disconnected")")
                            .font(.caption)
                        Text("Knowledge Service: \(apiManager.knowledgeServiceStatus ? "Connected" : "Disconnected")")
                            .font(.caption)
                    }
                    Button("Refresh Connection Status") {
                        apiManager.checkOverallConnectionStatus()
                    }
                    .foregroundColor(Color("MainColor"))
                }
            }
            .navigationTitle("API Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("MainColor"))
                }
            }
        }
        .onAppear {
            editableBaseURL = ConfigManager.shared.difyBaseURL
            editableChatAPIKey = ConfigManager.shared.difyChatAPIKey
            editableKnowledgeAPIKey = ConfigManager.shared.difyKnowledgeID
        }
    }
}

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSettingsView()
    }
}
