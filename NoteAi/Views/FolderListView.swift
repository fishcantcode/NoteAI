import SwiftUI

struct FolderListView: View {
     
    @StateObject var viewModel: FolderListViewModel  
    @StateObject var apiManager: APIManager  

    @State private var showingFolderInput = false
    @State private var newFolderName: String = ""
    @State private var showingConnectionSettings = false

     
    init(apiManager: APIManager) {
        _apiManager = StateObject(wrappedValue: apiManager)
        _viewModel = StateObject(wrappedValue: FolderListViewModel(apiManager: apiManager))
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 20)  
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {  
                 
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }

                 
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading Folders...")
                    Spacer()
                } else if viewModel.folders.isEmpty && viewModel.errorMessage == nil {
                    Spacer()
                    Text("No knowledge bases found.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.folders) { (folder: KnowledgeDataset) in  
                                NavigationLink(destination: FolderDetailView(dataset: folder, apiManager: apiManager)) {  
                                    FolderView(folderName: folder.name, folderIcon: "folder.fill")  
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteDataset(dataset: folder)
                                    } label: {
                                        Label("Delete Folder", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Knowledge Bases")  
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusIndicator()
                }
                ToolbarItem(placement: .navigationBarTrailing) {  
                    Button(action: {
                        showingFolderInput = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)  
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ConversationListView()) {
                        Image(systemName: "message.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {  
                    Button {
                        showingConnectionSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSettings) {
                ConnectionSettingsView()
            }
            .sheet(isPresented: $showingFolderInput) {
                 
                VStack {
                    Text("Create New Knowledge Base")
                        .font(.headline)
                        .padding()
                    TextField("Enter name", text: $newFolderName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    HStack {
                        Button("Cancel") {
                            showingFolderInput = false
                            newFolderName = ""
                        }
                        .padding()
                        Spacer()
                        Button("Create") {
                            if !newFolderName.isEmpty {
                                viewModel.createFolder(named: newFolderName)  
                                showingFolderInput = false
                                newFolderName = ""
                            }
                        }
                        .padding()
                    }
                }
                .padding()
                 
                .frame(minWidth: 300, idealHeight: 200)
            }
            .onAppear {
                viewModel.loadFolders()  
                apiManager.checkOverallConnectionStatus()  
            }
        }
    }
}

 
struct FolderView: View {
    let folderName: String
    let folderIcon: String  

    var body: some View {
        VStack {
            Image(systemName: folderIcon)
                .font(.system(size: 40))  
                .foregroundColor(.accentColor)
            Text(folderName)
                .font(.caption)  
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100)  
        .background(.thinMaterial)  
        .cornerRadius(10)  
    }
}

 
struct FolderListView_Previews: PreviewProvider {
    static var previews: some View {
         
        let mockAPIManager = APIManager()
         
         
        
         
        let mockViewModel = FolderListViewModel(apiManager: mockAPIManager)
         
         
         
         
         

         
         
         

         
         
         

        return FolderListView(apiManager: mockAPIManager)
             
    }
}
