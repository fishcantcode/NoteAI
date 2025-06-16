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
                            CreateNewFolderCardView {
                                showingFolderInput = true
                            }

                            ForEach(viewModel.folders) { (folder: KnowledgeDataset) in  
                                NavigationLink(destination: FolderDetailView(dataset: folder, apiManager: apiManager)) {  
                                    FolderView(folderName: folder.name)  
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
                    Text("Back").hidden()
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusIndicator()
                }
                ToolbarItem(placement: .navigationBarTrailing) {  
                    Button {
                        showingConnectionSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill").foregroundColor(Color("MainColor"))
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSettings) {
                ConnectionSettingsView()
            }

            .onAppear {
                viewModel.loadFolders()  
                apiManager.checkOverallConnectionStatus()  
            }
            .alert("Create New Knowledge Base", isPresented: $showingFolderInput) {
                TextField("Enter name", text: $newFolderName)
                Button("Create") {
                    if !newFolderName.isEmpty {
                        viewModel.createFolder(named: newFolderName)
                        newFolderName = "" 
                    }
                }
                Button("Cancel", role: .cancel) {
                    newFolderName = "" 
                }
            } message: {
                Text("Please enter a name for your new knowledge base.")
            }
        }
    }
}

 
struct CreateNewFolderCardView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) { 
                Image(systemName: "plus.circle.fill") 
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45) 
                    .foregroundColor(Color("MainColor")) 
                    .padding([.leading, .top], 25)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Create")
                    .font(.system(size: 16, weight: .semibold)) 
                    .foregroundColor(Color("MainColor")) 
                    .lineLimit(1)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 170, height: 210)
            .background(
                Image("folder_background")
                    .resizable()
                    .scaledToFill() 
                    .clipped()      
            )
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FolderView: View {
    let folderName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { 
            Image("fileicon") 
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45) 
                .padding([.leading, .top], 25)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(folderName)
                .font(.system(size: 16, weight: .semibold)) 
                .foregroundColor(Color("MainColor")) 
                .lineLimit(2)
                .padding(.horizontal, 25)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 170, height: 210)
        .background(
            Image("folder_background")
                .resizable()
                .scaledToFill() 
                .clipped()      
        )
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

 
struct FolderListView_Previews: PreviewProvider {
    static var previews: some View {
         
        let mockAPIManager = APIManager()

        let mockViewModel = FolderListViewModel(apiManager: mockAPIManager)

        return FolderListView(apiManager: mockAPIManager)
             
    }
}
