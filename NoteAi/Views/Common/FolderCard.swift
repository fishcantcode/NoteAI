import SwiftUI

struct FolderCard: View {
    let folder: Document  

     
    init(folder: Document) {
        guard folder.type == .folder else {
             
             
             
             
            self.folder = Document(id: UUID(), name: "Error: Not a Folder", type: .folder, creationDate: Date(), url: URL(string: "file:///error")!)
            return
        }
        self.folder = folder
    }

    var body: some View {
        ZStack {
            Image("file")  
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)

            VStack {
                Text(folder.name)  
                    .font(.headline)
                 
                Text("\(DocumentManager.shared.fileCount(in: folder.url)) Files")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}

 
struct FolderCard_Previews: PreviewProvider {
    static var previews: some View {
        let exampleFolderDoc = Document(id: UUID(), name: "Sample Project Folder", type: .folder, creationDate: Date(), url: URL(string: "file:///Users/fishfish/Project/fyp/FishFish/Swift/dataset_apiTest/NoteAi/NoteAi/SampleFolderPreview")!)
         
        return FolderCard(folder: exampleFolderDoc)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
